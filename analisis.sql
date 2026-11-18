/* =====================================================================
   PROYECTO CAPSTONE · ANÁLISIS EXPLORATORIO DE DATOS EN POSTGRESQL
   Archivo 2 de 2 : analisis.sql
   ---------------------------------------------------------------------
   Requisito previo: haber ejecutado estructura.sql en capstone_project.
   Cómo usarlo     : en pgAdmin, seleccionar UNA consulta (desde su
                     comentario hasta el punto y coma) y presionar F5.
   ---------------------------------------------------------------------
   DEFINICIONES DE NEGOCIO (aplican a todo el archivo)
   - Ingreso / venta : monto_neto = cantidad x precio_unitario x (1 - descuento).
   - Solo se cuentan pedidos con estado = 'Entregado'. Un pedido cancelado
     no generó dinero; incluirlo inflaría las ventas.
   - Moneda: pesos colombianos (COP).
   ===================================================================== */


/* =====================================================================
   P0 · AUDITORÍA DE CALIDAD: ¿LA LIMPIEZA FUNCIONÓ?
   Por qué: antes de sacar conclusiones hay que demostrar que los datos son
   confiables. Comparamos los nulos/vacíos de las columnas críticas en la
   zona cruda (staging) contra las tablas limpias. En las limpias deben
   ser 0, porque cada caso se resolvió con COALESCE en estructura.sql.
   ===================================================================== */
SELECT 'precio_unitario' AS columna_critica,
       COUNT(*) FILTER (WHERE NULLIF(TRIM(precio_unitario), '') IS NULL) AS nulos_en_crudo,
       (SELECT COUNT(*) FROM pedidos WHERE precio_unitario IS NULL)       AS nulos_en_limpio
FROM   stg_pedidos
UNION ALL
SELECT 'cantidad',
       COUNT(*) FILTER (WHERE NULLIF(TRIM(cantidad), '') IS NULL),
       (SELECT COUNT(*) FROM pedidos WHERE cantidad IS NULL)
FROM   stg_pedidos
UNION ALL
SELECT 'descuento',
       COUNT(*) FILTER (WHERE NULLIF(TRIM(descuento), '') IS NULL),
       (SELECT COUNT(*) FROM pedidos WHERE descuento IS NULL)
FROM   stg_pedidos
UNION ALL
SELECT 'canal',
       COUNT(*) FILTER (WHERE NULLIF(TRIM(canal), '') IS NULL),
       (SELECT COUNT(*) FROM pedidos WHERE canal IS NULL)
FROM   stg_pedidos
UNION ALL
SELECT 'precio_lista (catálogo)',
       (SELECT COUNT(*) FROM stg_productos WHERE NULLIF(TRIM(precio_lista), '') IS NULL),
       (SELECT COUNT(*) FROM productos     WHERE precio_lista IS NULL);

-- Control anti "explosión de filas": un pedido tiene 1 cliente y 1
-- producto, así que tras los JOIN debemos seguir teniendo 320 filas.
-- Si este número creciera, el JOIN estaría duplicando ventas.
SELECT (SELECT COUNT(*) FROM pedidos)                       AS filas_pedidos,
       COUNT(*)                                             AS filas_despues_del_join
FROM   pedidos   pe
JOIN   clientes  c ON c.cliente_id  = pe.cliente_id
JOIN   productos p ON p.producto_id = pe.producto_id;


/* =====================================================================
   P1 · TOP 5 CLIENTES POR GASTO TOTAL                (JOIN + GROUP BY + SUM)
   Pregunta de negocio: ¿quiénes son nuestros clientes más valiosos y
   cuánto dependemos de ellos? Sirve para diseñar un programa de lealtad
   y para medir el riesgo de perder a uno de ellos.
   Técnica extra: SUM(...) OVER () calcula el total de TODA la tienda en
   cada fila, así obtenemos el % de participación sin una subconsulta.
   ===================================================================== */
WITH gasto_por_cliente AS (
    SELECT c.cliente_id,
           c.nombre,
           c.ciudad,
           COUNT(pe.pedido_id)  AS pedidos_entregados,
           SUM(pe.monto_neto)   AS gasto_total
    FROM   clientes c
    JOIN   pedidos  pe ON pe.cliente_id = c.cliente_id
    WHERE  pe.estado = 'Entregado'          -- solo dinero realmente cobrado
    GROUP  BY c.cliente_id, c.nombre, c.ciudad
)
SELECT nombre,
       ciudad,
       pedidos_entregados,
       gasto_total,
       ROUND(gasto_total / pedidos_entregados, 0)                  AS ticket_promedio,
       ROUND(100 * gasto_total / SUM(gasto_total) OVER (), 1)      AS pct_de_ventas
FROM   gasto_por_cliente
ORDER  BY gasto_total DESC
LIMIT  5;


/* =====================================================================
   P2 · VENTAS TOTALES POR MES                        (funciones de fecha + LAG)
   Pregunta de negocio: ¿cómo se comporta la demanda durante el año?
   Detectar temporadas altas permite planear inventario de café tostado
   (que pierde frescura) y concentrar la pauta publicitaria.
   - DATE_TRUNC('month', fecha) agrupa todas las fechas de un mes.
   - LAG() trae la venta del mes anterior para calcular el crecimiento
     mes a mes sin perder el detalle de cada fila (Window Function).
   ===================================================================== */
WITH ventas_mes AS (
    SELECT DATE_TRUNC('month', fecha_pedido)::DATE AS mes,
           COUNT(*)                                AS pedidos,
           SUM(monto_neto)                         AS ventas
    FROM   pedidos
    WHERE  estado = 'Entregado'
    GROUP  BY 1
)
SELECT TO_CHAR(mes, 'YYYY-MM')                                   AS mes,
       pedidos,
       ventas,
       ROUND(100.0 * (ventas - LAG(ventas) OVER (ORDER BY mes))
                   / LAG(ventas) OVER (ORDER BY mes), 1)         AS crecimiento_vs_mes_anterior_pct,
       SUM(ventas) OVER (ORDER BY mes)                           AS ventas_acumuladas_del_anio
FROM   ventas_mes
ORDER  BY mes;

-- Vista por trimestre: confirma la estacionalidad con menos "ruido".
SELECT 'T' || EXTRACT(QUARTER FROM fecha_pedido)  AS trimestre,
       SUM(monto_neto)                            AS ventas,
       ROUND(100 * SUM(monto_neto) / SUM(SUM(monto_neto)) OVER (), 1) AS pct_del_anio
FROM   pedidos
WHERE  estado = 'Entregado'
GROUP  BY 1
ORDER  BY 1;


/* =====================================================================
   P3 · LOS 3 PRODUCTOS MENOS VENDIDOS                (LEFT JOIN + COALESCE)
   Pregunta de negocio: ¿qué productos ocupan catálogo e inventario sin
   rotar? Candidatos a promoción, combo o salida del catálogo.
   Clave: usamos LEFT JOIN desde productos. Con un JOIN normal, un
   producto que NUNCA se vendió desaparecería del resultado... y es
   justamente el que más nos interesa encontrar. COALESCE convierte su
   NULL en 0 para que pueda ordenarse y leerse correctamente.
   ===================================================================== */
SELECT p.nombre,
       p.categoria,
       p.precio_lista,
       COALESCE(SUM(pe.cantidad), 0)    AS unidades_vendidas,
       COALESCE(SUM(pe.monto_neto), 0)  AS ingresos
FROM   productos p
LEFT   JOIN pedidos pe
       ON  pe.producto_id = p.producto_id
       AND pe.estado = 'Entregado'      -- el filtro va en el ON, no en WHERE,
                                        -- para no anular el efecto del LEFT JOIN
GROUP  BY p.producto_id, p.nombre, p.categoria, p.precio_lista
ORDER  BY unidades_vendidas ASC, ingresos ASC
LIMIT  3;


/* =====================================================================
   P4 · RANKING DE PEDIDOS POR CATEGORÍA              (RANK() + PARTITION BY)
   Pregunta de negocio: dentro de cada categoría, ¿cuáles son los pedidos
   más grandes? Revela qué tipo de compra "grande" ocurre en cada línea
   (por ejemplo, regalos corporativos o compras al por mayor).
   - PARTITION BY categoria reinicia el ranking en cada categoría.
   - RANK() da el mismo puesto a montos empatados y salta el siguiente
     (1, 1, 3), a diferencia de ROW_NUMBER() que nunca empata.
   Mostramos el top 3 de cada categoría.
   ===================================================================== */
WITH ranking AS (
    SELECT p.categoria,
           pe.pedido_id,
           c.nombre          AS cliente,
           p.nombre          AS producto,
           pe.cantidad,
           pe.monto_neto,
           RANK() OVER (PARTITION BY p.categoria
                        ORDER BY pe.monto_neto DESC) AS puesto_en_categoria
    FROM   pedidos   pe
    JOIN   productos p ON p.producto_id = pe.producto_id
    JOIN   clientes  c ON c.cliente_id  = pe.cliente_id
    WHERE  pe.estado = 'Entregado'
)
SELECT *
FROM   ranking
WHERE  puesto_en_categoria <= 3       -- no se puede filtrar RANK() en el WHERE
ORDER  BY categoria, puesto_en_categoria;  -- de la misma consulta: por eso el CTE

-- Complemento: ranking de CATEGORÍAS por ingresos y su peso en la tienda.
SELECT p.categoria,
       SUM(pe.monto_neto)                                          AS ingresos,
       RANK() OVER (ORDER BY SUM(pe.monto_neto) DESC)              AS ranking,
       ROUND(100 * SUM(pe.monto_neto) / SUM(SUM(pe.monto_neto)) OVER (), 1) AS pct_ingresos
FROM   pedidos   pe
JOIN   productos p ON p.producto_id = pe.producto_id
WHERE  pe.estado = 'Entregado'
GROUP  BY p.categoria
ORDER  BY ranking;


/* =====================================================================
   P5 · SEGMENTACIÓN DE CLIENTES (PERFIL DEL CLIENTE LEAL)   (CASE + CTE)
   Pregunta de negocio: ¿cuál es el perfil de nuestro cliente más leal y
   cuánto pesa cada segmento? Clasificamos por frecuencia de compra
   porque en café la recompra es el motor del negocio (es un consumible).
   Umbrales: 15+ pedidos = Leal (más de uno al mes), 8-14 = Recurrente,
   menos de 8 = Ocasional.
   ===================================================================== */
WITH comportamiento AS (
    SELECT c.cliente_id,
           COUNT(*)            AS pedidos,
           SUM(pe.monto_neto)  AS gasto
    FROM   clientes c
    JOIN   pedidos  pe ON pe.cliente_id = c.cliente_id
    WHERE  pe.estado = 'Entregado'
    GROUP  BY c.cliente_id
),
segmentado AS (
    SELECT *,
           CASE
               WHEN pedidos >= 15 THEN '1. Leal'
               WHEN pedidos >= 8  THEN '2. Recurrente'
               ELSE                    '3. Ocasional'
           END AS segmento
    FROM   comportamiento
)
SELECT segmento,
       COUNT(*)                                            AS clientes,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS pct_clientes,
       SUM(gasto)                                          AS ventas,
       ROUND(100 * SUM(gasto) / SUM(SUM(gasto)) OVER (), 1) AS pct_ventas,
       ROUND(AVG(gasto), 0)                                AS gasto_promedio_por_cliente
FROM   segmentado
GROUP  BY segmento
ORDER  BY segmento;


/* =====================================================================
   P6 · ¿DÓNDE PERDEMOS VENTAS? CANCELACIONES POR CANAL  (CASE dentro de SUM)
   Pregunta de negocio: ¿qué canal convierte peor? Un pedido cancelado es
   una venta que ya habíamos ganado y se perdió en el último paso.
   Técnica: SUM(CASE WHEN ... THEN 1 ELSE 0 END) cuenta condicionalmente
   en una sola pasada, sin hacer una consulta por estado.
   También comparamos 1er vs 2do semestre para ver cómo cambió la mezcla.
   ===================================================================== */
SELECT canal,
       COUNT(*)                                                         AS pedidos_totales,
       SUM(CASE WHEN estado = 'Cancelado' THEN 1 ELSE 0 END)            AS cancelados,
       ROUND(100.0 * SUM(CASE WHEN estado = 'Cancelado' THEN 1 ELSE 0 END)
                   / COUNT(*), 1)                                       AS tasa_cancelacion_pct,
       SUM(CASE WHEN estado = 'Cancelado' THEN monto_neto ELSE 0 END)   AS ventas_perdidas,
       SUM(CASE WHEN estado = 'Entregado' AND fecha_pedido <  '2025-07-01' THEN 1 ELSE 0 END) AS entregados_1er_sem,
       SUM(CASE WHEN estado = 'Entregado' AND fecha_pedido >= '2025-07-01' THEN 1 ELSE 0 END) AS entregados_2do_sem
FROM   pedidos
GROUP  BY canal
ORDER  BY tasa_cancelacion_pct DESC;


/* =====================================================================
   P7 · VENTAS Y TICKET PROMEDIO POR CIUDAD           (JOIN + GROUP BY)
   Pregunta de negocio: ¿dónde está concentrada la demanda? Orienta
   decisiones de logística (bodegas, transportadora) y pauta geográfica.
   Los clientes sin ciudad aparecen como 'Sin dato' gracias a la limpieza:
   no se pierden, y además dimensionan un problema de captura de datos.
   ===================================================================== */
SELECT c.ciudad,
       COUNT(DISTINCT c.cliente_id)         AS clientes,
       COUNT(pe.pedido_id)                  AS pedidos,
       SUM(pe.monto_neto)                   AS ventas,
       ROUND(AVG(pe.monto_neto), 0)         AS ticket_promedio
FROM   clientes c
JOIN   pedidos  pe ON pe.cliente_id = c.cliente_id
WHERE  pe.estado = 'Entregado'
GROUP  BY c.ciudad
ORDER  BY ventas DESC;
