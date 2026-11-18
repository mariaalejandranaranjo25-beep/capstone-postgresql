/* =====================================================================
   PROYECTO CAPSTONE · ANÁLISIS EXPLORATORIO DE DATOS EN POSTGRESQL
   Archivo 1 de 2 : estructura.sql
   ---------------------------------------------------------------------
   Negocio      : "Grano de Origen", tienda online de café de especialidad
                  colombiano (café en grano, molido, cápsulas, accesorios,
                  kits de regalo y suscripciones).
   Período      : enero a diciembre de 2025.
   Qué hace     : 1) Crea una zona "staging" con los datos TAL COMO LLEGAN
                     (todo en texto, con errores reales de captura).
                  2) Crea las tablas definitivas con tipos correctos
                     (DATE, NUMERIC, INTEGER) y reglas de integridad.
                  3) Limpia y transforma staging -> tablas definitivas
                     usando TRIM, INITCAP, NULLIF, COALESCE y CASE.
                  4) Verifica que la carga quedó bien.
   Motor        : PostgreSQL 13 o superior (probado en PostgreSQL 16).
   ---------------------------------------------------------------------
   CÓMO EJECUTARLO
   Paso A. Crear la base de datos (una sola vez). En pgAdmin: clic derecho
           en "Databases" > Create > Database > nombre: capstone_project.
           O bien, conectado a la base "postgres", ejecutar:
               CREATE DATABASE capstone_project;
   Paso B. Abrir el Query Tool SOBRE capstone_project, pegar TODO este
           archivo y ejecutarlo (F5). El script se puede correr varias
           veces: al inicio borra lo que haya creado antes.
   ===================================================================== */


/* =====================================================================
   SECCIÓN 0 · REINICIO
   Por qué: permite volver a ejecutar el script desde cero sin errores de
   "la tabla ya existe". CASCADE elimina también las llaves foráneas.
   ===================================================================== */
DROP TABLE IF EXISTS pedidos       CASCADE;
DROP TABLE IF EXISTS productos     CASCADE;
DROP TABLE IF EXISTS clientes      CASCADE;
DROP TABLE IF EXISTS stg_pedidos   CASCADE;
DROP TABLE IF EXISTS stg_productos CASCADE;
DROP TABLE IF EXISTS stg_clientes  CASCADE;


/* =====================================================================
   SECCIÓN 1 · ZONA STAGING (DATOS CRUDOS)
   Por qué todo en TEXT: así llegan los datos desde un CSV o un formulario
   web. Si los cargáramos directo a columnas DATE o NUMERIC, la carga
   fallaría con la primera fecha en formato distinto. Primero recibimos
   todo, después lo limpiamos con reglas explícitas y documentadas.
   ===================================================================== */
CREATE TABLE stg_clientes (
    cliente_id      INTEGER,
    nombre          TEXT,
    email           TEXT,
    ciudad          TEXT,
    fecha_registro  TEXT      -- llega mezclado: 'AAAA-MM-DD' y 'DD/MM/AAAA'
);

CREATE TABLE stg_productos (
    producto_id     INTEGER,
    nombre          TEXT,
    categoria       TEXT,     -- llega con mayúsculas, tildes y espacios inconsistentes
    precio_lista    TEXT      -- 2 productos sin precio en el catálogo
);

CREATE TABLE stg_pedidos (
    pedido_id       INTEGER,
    cliente_id      INTEGER,
    producto_id     INTEGER,
    fecha_pedido    TEXT,     -- formatos mixtos
    cantidad        TEXT,     -- algunos vacíos
    precio_unitario TEXT,     -- algunos vacíos (columna crítica)
    descuento       TEXT,     -- vacío = no se registró descuento
    canal           TEXT,     -- 'web', 'WEB', 'Web', vacío...
    estado          TEXT      -- 'entregado', 'ENTREGADO', 'Entregado '...
);


/* =====================================================================
   SECCIÓN 2 · CARGA DE DATOS CRUDOS
   Errores sembrados a propósito para simular datos reales:
     - clientes : nombres en minúscula/mayúscula/con espacios, emails en
                  mayúscula, ciudades vacías o mal escritas, 2 registros
                  duplicados y fechas en dos formatos.
     - productos: categorías escritas de 3-4 maneras distintas y 2
                  productos sin precio de lista.
     - pedidos  : ~6 % sin precio unitario, ~3 % sin cantidad, descuento
                  vacío, canal y estado inconsistentes, fechas en dos
                  formatos y 3 pedidos duplicados por doble carga.
   ===================================================================== */
INSERT INTO stg_clientes (cliente_id, nombre, email, ciudad, fecha_registro) VALUES
  (1, 'valentina gómez', 'valentina.gomez@correo.com', 'Armenia', '2024-11-26'),
  (2, 'Santiago Restrepo', 'santiago.restrepo@correo.com', 'Pereira', '2024-09-01'),
  (3, '  Camila Ospina', 'camila.ospina@correo.com', 'Manizales', '2024-03-29'),
  (4, 'ANDRÉS CASTAÑO', 'andres.castano@correo.com', 'Bogota', '01/01/2024'),
  (5, 'Laura Jaramillo', 'laura.jaramillo@correo.com', 'Medellín', '2024-07-09'),
  (6, 'Juan Pablo Marín', 'JUAN.MARIN@CORREO.COM', ' Armenia', '2024-10-18'),
  (7, 'Daniela Quintero', 'daniela.quintero@correo.com', 'Cali', '2024-04-28'),
  (8, 'mateo arango', 'mateo.arango@correo.com', 'Calarcá', '03/02/2024'),
  (9, 'Isabella Duque', 'isabella.duque@correo.com', 'bogota', '2024-07-24'),
  (10, 'Sebastián Henao', 'sebastian.henao@correo.com', 'Pereira', '2024-02-20'),
  (11, 'Mariana López', 'mariana.lopez@correo.com', NULL, '2024-01-23'),
  (12, 'Felipe Cardona', 'FELIPE.CARDONA@CORREO.COM', 'Medellín', '01/03/2024'),
  (13, 'Natalia Giraldo ', 'natalia.giraldo@correo.com', 'armenia', '2024-07-11'),
  (14, 'Tomás Valencia', 'tomas.valencia@correo.com', 'Bogotá', '2024-07-29'),
  (15, 'Sofía Ramírez', 'sofia.ramirez@correo.com', '', '2024-01-26'),
  (16, 'Alejandro Muñoz', 'alejandro.munoz@correo.com', 'Cali', '09/11/2024'),
  (17, 'Paula Hoyos', 'paula.hoyos@correo.com', 'Manizales', '2024-01-15'),
  (18, 'David Zuluaga', 'DAVID.ZULUAGA@CORREO.COM', 'Armenia', '2025-02-02'),
  (19, 'Juliana Ríos', 'juliana.rios@correo.com', 'Bogotá', '2025-01-29'),
  (20, 'Carlos Salazar', 'carlos.salazar@correo.com', 'Pereira', '06/04/2024'),
  (21, 'Manuela Toro', 'manuela.toro@correo.com', 'Medellín', '2024-01-14'),
  (22, 'Esteban Arias', 'esteban.arias@correo.com', NULL, '2024-12-28'),
  (23, 'Gabriela Vélez', 'gabriela.velez@correo.com', 'Bogotá', '2025-02-06'),
  (24, 'Nicolás Patiño', 'NICOLAS.PATINO@CORREO.COM', ' Armenia', '23/08/2024'),
  (25, 'Luisa Fernanda Mejía', 'luisa.mejia@correo.com', 'Montenegro', '2024-06-30'),
  (5, 'Laura Jaramillo', 'laura.jaramillo@correo.com', 'Medellín', '2024-07-09'),
  (12, 'Felipe Cardona', 'FELIPE.CARDONA@CORREO.COM', 'Medellín', '01/03/2024');

INSERT INTO stg_productos (producto_id, nombre, categoria, precio_lista) VALUES
  (1, 'Café Tostión Media 500 g', 'Café en grano', '42000'),
  (2, 'Café Tostión Oscura 500 g', 'café en grano', '42000'),
  (3, 'Café Geisha Microlote 250 g', 'CAFÉ EN GRANO ', '78000'),
  (4, 'Café Honey Process 250 g', 'Café en Grano', NULL),
  (5, 'Café Molido Tradicional 500 g', 'Café molido', '36000'),
  (6, 'Café Molido Descafeinado 250 g', 'cafe molido', '31000'),
  (7, 'Cápsulas Compatibles x10', 'Cápsulas', '24000'),
  (8, 'Cápsulas Intensas x10', 'capsulas', '25000'),
  (9, 'Prensa Francesa 600 ml', 'Accesorios', '89000'),
  (10, 'Filtro V60 Cerámico', 'accesorios ', '115000'),
  (11, 'Molino Manual de Acero', 'Accesorios', '165000'),
  (12, 'Kit Degustación 4 Orígenes', 'Kits y regalos', '98000'),
  (13, 'Caja Regalo Navideña', 'kits y regalos', NULL),
  (14, 'Suscripción Mensual Café', 'Suscripciones', '120000'),
  (15, 'Taza Esmaltada Artesanal', 'Accesorios', '38000');

INSERT INTO stg_pedidos (pedido_id, cliente_id, producto_id, fecha_pedido, cantidad, precio_unitario, descuento, canal, estado) VALUES
  (1001, 12, 6, '01/08/2025', '1', '31000', NULL, 'instagram', 'CANCELADO'),
  (1002, 17, 2, '2025-07-19', '1', '42000', '0.05', 'Instagram', 'ENTREGADO'),
  (1003, 6, 2, '27/12/2025', '1', '42000', NULL, 'web', 'ENTREGADO'),
  (1004, 20, 1, '2025-08-05', '4', '42000', '0.05', 'Instagram', 'ENTREGADO'),
  (1005, 9, 12, '2025-09-17', '1', '98000', NULL, 'WEB', 'Entregado'),
  (1006, 3, 2, '2025-02-14', '1', '42000', '0.10', 'WEB', 'ENTREGADO'),
  (1007, 9, 6, '2025-03-08', '1', '31000', '0.05', 'WEB', 'entregado'),
  (1008, 16, 3, '2025-01-25', '1', '78000', NULL, 'WHATSAPP', 'Entregado '),
  (1009, 7, 6, '20/09/2025', '1', '31000', '0.10', 'WEB', 'entregado'),
  (1010, 13, 7, '2025-08-06', NULL, '24000', NULL, 'WHATSAPP', 'ENTREGADO'),
  (1011, 13, 7, '2025-11-08', '1', '24000', NULL, 'Instagram', 'ENTREGADO'),
  (1012, 2, 14, '2025-07-21', '1', '120000', '0.05', 'instagram', 'Entregado '),
  (1013, 3, 1, '14/12/2025', '2', '42000', NULL, 'Web', 'ENTREGADO'),
  (1014, 18, 4, '23/02/2025', '1', '64000', NULL, 'whatsapp', 'Entregado'),
  (1015, 13, 3, '2025-10-25', '1', '78000', '0.10', 'web', 'ENTREGADO'),
  (1016, 3, 1, '2025-09-21', '2', '42000', NULL, 'WHATSAPP', 'Cancelado'),
  (1017, 15, 1, '2025-06-09', '2', '42000', NULL, 'Web', 'Entregado'),
  (1018, 20, 1, '2025-08-27', '1', '42000', NULL, 'WEB', 'Entregado'),
  (1019, 15, 12, '2025-03-03', '1', '98000', NULL, 'WHATSAPP', 'entregado'),
  (1020, 5, 8, '2025-10-03', '1', '25000', NULL, 'Instagram', 'ENTREGADO'),
  (1021, 18, 3, '2025-08-10', '1', '78000', '0', 'WhatsApp', 'ENTREGADO'),
  (1022, 16, 1, '2025-05-21', '1', '42000', '0.05', 'WhatsApp', 'Entregado'),
  (1023, 13, 9, '2025-05-26', '1', '89000', NULL, 'INSTAGRAM', 'CANCELADO'),
  (1024, 20, 5, '2025-05-01', '3', '36000', '0.10', 'INSTAGRAM', 'CANCELADO'),
  (1025, 18, 2, '2025-12-09', '1', '42000', '0', 'Web', 'entregado'),
  (1026, 18, 3, '2025-10-07', '1', '78000', NULL, 'INSTAGRAM', 'Entregado'),
  (1027, 6, 1, '2025-07-23', '1', '42000', '0', 'instagram', 'ENTREGADO'),
  (1028, 3, 5, '2025-01-20', '2', '36000', NULL, 'WhatsApp', 'entregado'),
  (1029, 6, 1, '09/10/2025', '1', NULL, '0.10', 'WEB', 'ENTREGADO'),
  (1030, 18, 8, '2025-05-04', '1', '25000', NULL, 'WhatsApp', 'ENTREGADO'),
  (1031, 4, 6, '2025-12-18', '2', '31000', NULL, 'WHATSAPP', 'Entregado'),
  (1032, 18, 6, '2025-06-11', '3', '31000', '0.10', 'whatsapp', 'entregado'),
  (1033, 18, 5, '2025-08-02', '1', '36000', NULL, 'web', 'Cancelado '),
  (1034, 3, 4, '2025-10-05', '1', '64000', NULL, 'instagram', 'Entregado '),
  (1035, 21, 14, '2025-06-19', '2', '120000', '0.05', 'Web', 'Entregado '),
  (1036, 9, 7, '2025-10-02', '2', '24000', '0', 'Web', 'ENTREGADO'),
  (1037, 7, 5, '07/10/2025', '2', '36000', NULL, 'INSTAGRAM', 'ENTREGADO'),
  (1038, 4, 12, '2025-09-05', '1', '98000', '0', 'WhatsApp', 'ENTREGADO'),
  (1039, 24, 14, '03/11/2025', '1', '120000', NULL, 'instagram', 'Entregado'),
  (1040, 13, 1, '2025-03-18', '1', '42000', '0', 'web', 'Entregado'),
  (1041, 6, 8, '12/04/2025', '1', '25000', NULL, 'WEB', 'ENTREGADO'),
  (1042, 13, 11, '2025-06-09', '1', '165000', NULL, 'WHATSAPP', 'ENTREGADO'),
  (1043, 12, 5, '2025-03-19', '2', '36000', NULL, 'whatsapp', 'entregado'),
  (1044, 22, 14, '25/05/2025', '3', '120000', '0', 'Web', 'Entregado '),
  (1045, 13, 5, '2025-11-14', '3', '36000', NULL, 'Web', 'ENTREGADO'),
  (1046, 20, 7, '2025-12-24', '1', NULL, NULL, 'Instagram', 'Entregado'),
  (1047, 11, 8, '16/04/2025', '2', '25000', '0', 'web', 'Entregado'),
  (1048, 13, 1, '2025-06-13', '1', '42000', NULL, 'Web', 'entregado'),
  (1049, 13, 2, '2025-04-14', '1', '42000', '0.10', 'WhatsApp', 'ENTREGADO'),
  (1050, 10, 8, '2025-03-21', '1', '25000', NULL, 'web', 'Entregado'),
  (1051, 6, 5, '2025-05-06', '1', '36000', NULL, 'whatsapp', 'Entregado '),
  (1052, 17, 1, '11/03/2025', NULL, '42000', '0', 'WEB', 'ENTREGADO'),
  (1053, 1, 8, '2025-12-13', '2', '25000', '0.10', 'INSTAGRAM', 'entregado'),
  (1054, 12, 14, '2025-03-16', '1', '120000', '0', 'web', 'entregado'),
  (1055, 2, 2, '2025-10-10', '3', '42000', '0', 'Web', 'entregado'),
  (1056, 3, 5, '2025-11-18', '1', '36000', NULL, NULL, 'ENTREGADO'),
  (1057, 13, 2, '2025-03-04', '2', '42000', NULL, 'WEB', 'ENTREGADO'),
  (1058, 3, 1, '2025-03-05', '2', NULL, '0.10', 'Web', 'Entregado '),
  (1059, 1, 1, '06/09/2025', '1', '42000', NULL, 'Instagram', 'Entregado'),
  (1060, 17, 4, '2025-05-27', '1', '64000', NULL, 'INSTAGRAM', 'entregado'),
  (1061, 22, 1, '2025-01-23', '1', '42000', NULL, 'web', 'Entregado '),
  (1062, 13, 5, '2025-05-15', '1', '36000', NULL, 'WEB', 'ENTREGADO'),
  (1063, 2, 1, '03/12/2025', '1', '42000', NULL, 'web', 'Entregado '),
  (1064, 1, 4, '09/11/2025', '1', '64000', NULL, 'INSTAGRAM', 'CANCELADO'),
  (1065, 8, 9, '23/09/2025', '1', '89000', '0.05', 'INSTAGRAM', 'Entregado'),
  (1066, 8, 12, '2025-10-06', '3', '98000', '0', 'WHATSAPP', 'ENTREGADO'),
  (1067, 12, 9, '2025-09-20', '1', '89000', NULL, 'INSTAGRAM', 'entregado'),
  (1068, 9, 8, '2025-07-22', '1', '25000', '0', 'WEB', 'ENTREGADO'),
  (1069, 6, 9, '2025-01-20', '3', '89000', '0.10', 'WEB', 'Entregado'),
  (1070, 18, 6, '23/05/2025', '1', '31000', '0.10', 'WHATSAPP', 'Entregado'),
  (1071, 18, 5, '2025-09-01', '1', '36000', NULL, 'INSTAGRAM', 'cancelado'),
  (1072, 1, 6, '2025-10-23', '1', '31000', NULL, 'Web', 'Entregado'),
  (1073, 3, 1, '2025-10-01', '1', '42000', NULL, 'WEB', 'ENTREGADO'),
  (1074, 19, 7, '13/10/2025', '1', '24000', NULL, 'Instagram', 'ENTREGADO'),
  (1075, 22, 6, '2025-09-20', '1', '31000', '0', 'INSTAGRAM', 'ENTREGADO'),
  (1076, 9, 5, '2025-12-04', '1', '36000', NULL, 'web', 'Entregado'),
  (1077, 12, 7, '2025-11-03', '2', '24000', '0.05', 'instagram', 'Entregado '),
  (1078, 7, 3, '2025-12-14', '1', '78000', NULL, 'Web', 'entregado'),
  (1079, 3, 2, '2025-01-12', '1', '42000', NULL, 'WHATSAPP', 'Entregado '),
  (1080, 18, 5, '09/06/2025', '2', '36000', NULL, 'Web', 'ENTREGADO'),
  (1081, 16, 8, '2025-10-04', '2', '25000', '0.05', 'instagram', 'Entregado '),
  (1082, 9, 1, '2025-07-09', '1', '42000', NULL, 'Web', 'Entregado'),
  (1083, 3, 4, '13/07/2025', '1', '64000', NULL, 'WEB', 'ENTREGADO'),
  (1084, 9, 2, '2025-12-11', '3', '42000', '0', 'INSTAGRAM', 'Entregado'),
  (1085, 6, 1, '2025-12-19', '1', '42000', NULL, 'instagram', 'entregado'),
  (1086, 6, 2, '2025-09-14', '1', '42000', NULL, 'whatsapp', 'ENTREGADO'),
  (1087, 6, 8, '2025-02-27', '1', '25000', '0.10', 'Web', 'ENTREGADO'),
  (1088, 9, 1, '2025-07-19', '4', '42000', '0.05', 'web', 'entregado'),
  (1089, 9, 1, '2025-02-03', '3', '42000', NULL, 'WEB', 'ENTREGADO'),
  (1090, 6, 7, '20/05/2025', '1', '24000', '0.10', 'WHATSAPP', 'ENTREGADO'),
  (1091, 13, 2, '2025-10-02', '1', '42000', '0', 'INSTAGRAM', 'Entregado'),
  (1092, 7, 6, '02/10/2025', NULL, '31000', '0', 'Instagram', 'Cancelado '),
  (1093, 16, 5, '2025-04-28', '1', '36000', NULL, 'Instagram', 'ENTREGADO'),
  (1094, 6, 1, '2025-11-08', '1', '42000', '0', 'web', 'entregado'),
  (1095, 18, 2, '2025-05-21', '1', '42000', NULL, 'whatsapp', 'ENTREGADO'),
  (1096, 4, 1, '2025-12-12', '1', '42000', NULL, 'Instagram', 'Entregado'),
  (1097, 11, 6, '2025-05-24', '3', '31000', '0', 'WhatsApp', 'CANCELADO'),
  (1098, 3, 3, '2025-12-04', '1', '78000', '0.05', NULL, 'Entregado'),
  (1099, 1, 7, '2025-11-08', '1', '24000', NULL, 'Instagram', 'Cancelado '),
  (1100, 19, 3, '2025-08-16', '1', '78000', '0.05', 'web', 'Entregado '),
  (1101, 6, 7, '2025-07-26', '1', '24000', '0.05', 'INSTAGRAM', 'Cancelado '),
  (1102, 24, 7, '2025-10-08', '2', '24000', NULL, 'WhatsApp', 'entregado'),
  (1103, 12, 12, '11/10/2025', '1', '98000', '0', 'web', 'entregado'),
  (1104, 9, 12, '2025-06-07', '4', NULL, '0', 'WHATSAPP', 'ENTREGADO'),
  (1105, 3, 5, '2025-12-13', '1', '36000', NULL, 'Web', 'Entregado '),
  (1106, 13, 8, '21/04/2025', '1', NULL, '0.10', 'instagram', 'entregado'),
  (1107, 22, 1, '20/11/2025', '1', '42000', '0.05', 'WEB', 'Entregado '),
  (1108, 7, 8, '2025-12-14', '4', '25000', NULL, 'WEB', 'Entregado '),
  (1109, 18, 1, '2025-06-16', '1', '42000', '0.05', 'WhatsApp', 'entregado'),
  (1110, 17, 7, '2025-12-16', '1', '24000', '0', 'WhatsApp', 'ENTREGADO'),
  (1111, 6, 5, '2025-06-10', '4', '36000', NULL, 'WEB', 'Entregado '),
  (1112, 14, 5, '2025-04-20', '1', '36000', NULL, 'web', 'Entregado '),
  (1113, 13, 7, '2025-11-13', '2', '24000', NULL, 'instagram', 'Cancelado'),
  (1114, 23, 14, '12/12/2025', '1', '120000', '0', 'Instagram', 'CANCELADO'),
  (1115, 13, 5, '2025-12-27', '2', '36000', NULL, 'instagram', 'Entregado '),
  (1116, 6, 5, '2025-11-12', NULL, '36000', NULL, 'instagram', 'Entregado '),
  (1117, 6, 7, '21/01/2025', '1', '24000', NULL, 'Web', 'entregado'),
  (1118, 5, 1, '22/06/2025', '1', '42000', '0.05', 'Web', 'Entregado'),
  (1119, 16, 4, '2025-08-05', '1', '64000', NULL, 'instagram', 'CANCELADO'),
  (1120, 20, 1, '2025-11-07', '2', '42000', NULL, 'web', 'Entregado'),
  (1121, 9, 5, '2025-12-16', '3', '36000', '0.05', 'Web', 'Entregado'),
  (1122, 18, 5, '20/06/2025', '1', '36000', NULL, 'Instagram', 'cancelado'),
  (1123, 21, 4, '2025-10-25', '1', '64000', NULL, NULL, 'entregado'),
  (1124, 6, 1, '2025-12-11', '1', '42000', '0.10', 'web', 'entregado'),
  (1125, 8, 3, '2025-04-18', '3', '78000', '0', 'WhatsApp', 'ENTREGADO'),
  (1126, 18, 9, '2025-05-18', '1', '89000', '0', 'whatsapp', 'entregado'),
  (1127, 13, 7, '2025-04-08', '4', '24000', NULL, 'Web', 'Entregado '),
  (1128, 9, 7, '2025-01-01', '2', '24000', NULL, 'INSTAGRAM', 'Entregado'),
  (1129, 3, 14, '18/10/2025', '1', '120000', '0.10', 'web', 'Entregado '),
  (1130, 9, 9, '2025-05-21', '2', '89000', NULL, 'Web', 'ENTREGADO'),
  (1131, 6, 3, '12/04/2025', '1', '78000', NULL, 'WHATSAPP', 'Entregado'),
  (1132, 1, 5, '2025-12-05', '1', '36000', '0.10', 'instagram', 'entregado'),
  (1133, 14, 14, '2025-12-19', '1', '120000', '0.10', 'WEB', 'Entregado'),
  (1134, 9, 1, '17/12/2025', '1', '42000', '0.10', 'INSTAGRAM', 'ENTREGADO'),
  (1135, 12, 5, '2025-08-20', '3', '36000', '0', 'WHATSAPP', 'Entregado'),
  (1136, 21, 13, '15/11/2025', '1', '135000', '0.10', 'INSTAGRAM', 'ENTREGADO'),
  (1137, 9, 1, '2025-10-17', '1', '42000', NULL, 'web', 'entregado'),
  (1138, 13, 14, '2025-12-08', '1', '120000', NULL, 'WEB', 'CANCELADO'),
  (1139, 3, 8, '2025-12-05', '1', '25000', '0.05', 'Instagram', 'Entregado '),
  (1140, 6, 9, '2025-12-09', '1', '89000', '0', 'Instagram', 'Cancelado'),
  (1141, 20, 9, '2025-11-07', '1', '89000', '0.05', 'instagram', 'entregado'),
  (1142, 18, 12, '25/02/2025', '2', '98000', NULL, 'Web', 'Entregado '),
  (1143, 3, 7, '2025-01-16', '4', '24000', NULL, 'web', 'Entregado '),
  (1144, 14, 7, '05/10/2025', '1', '24000', '0.10', 'Web', 'Entregado '),
  (1145, 15, 7, '2025-08-05', '2', '24000', '0.05', 'web', 'entregado'),
  (1146, 10, 12, '2025-08-04', '1', '98000', NULL, 'instagram', 'Entregado'),
  (1147, 14, 1, '2025-12-17', '1', '42000', NULL, 'web', 'CANCELADO'),
  (1148, 9, 8, '2025-03-14', '1', '25000', NULL, 'Web', 'Entregado'),
  (1149, 6, 2, '2025-02-23', '3', '42000', '0', 'WhatsApp', 'ENTREGADO'),
  (1150, 13, 1, '2025-06-19', '1', NULL, '0.05', 'WhatsApp', 'Entregado'),
  (1151, 17, 7, '04/12/2025', '1', '24000', '0.05', 'INSTAGRAM', 'Entregado'),
  (1152, 3, 1, '2025-10-22', '2', '42000', NULL, 'WEB', 'ENTREGADO'),
  (1153, 13, 7, '20/11/2025', '3', '24000', '0.10', 'Instagram', 'Entregado '),
  (1154, 18, 5, '26/11/2025', '1', '36000', '0.10', 'Web', 'Entregado '),
  (1155, 18, 8, '05/06/2025', '1', '25000', NULL, 'Web', 'entregado'),
  (1156, 3, 1, '2025-03-19', '2', '42000', NULL, 'whatsapp', 'Entregado '),
  (1157, 5, 7, '2025-11-13', '3', '24000', '0', NULL, 'Entregado '),
  (1158, 15, 5, '2025-06-25', '2', '36000', '0', 'web', 'entregado'),
  (1159, 18, 1, '2025-08-07', '2', '42000', '0', 'Instagram', 'ENTREGADO'),
  (1160, 13, 1, '26/06/2025', '1', '42000', NULL, 'whatsapp', 'ENTREGADO'),
  (1161, 18, 12, '2025-05-01', '1', '98000', NULL, 'web', 'ENTREGADO'),
  (1162, 8, 5, '03/07/2025', '1', '36000', '0.05', 'WEB', 'entregado'),
  (1163, 13, 2, '2025-07-07', '1', '42000', NULL, 'WhatsApp', 'ENTREGADO'),
  (1164, 6, 2, '18/07/2025', '1', '42000', NULL, 'web', 'entregado'),
  (1165, 17, 7, '01/05/2025', '3', '24000', '0.10', 'WEB', 'ENTREGADO'),
  (1166, 24, 1, '2025-04-18', '4', '42000', '0.05', 'INSTAGRAM', 'Entregado '),
  (1167, 9, 3, '2025-09-25', '1', '78000', NULL, 'whatsapp', 'CANCELADO'),
  (1168, 10, 2, '2025-07-06', '1', NULL, NULL, 'Web', 'Entregado'),
  (1169, 25, 5, '11/05/2025', NULL, '36000', NULL, 'Web', 'entregado'),
  (1170, 12, 8, '2025-12-08', '2', '25000', NULL, 'INSTAGRAM', 'entregado'),
  (1171, 9, 5, '2025-04-12', '3', '36000', NULL, 'WEB', 'Entregado '),
  (1172, 12, 4, '2025-11-21', '1', '64000', NULL, 'instagram', 'entregado'),
  (1173, 3, 7, '2025-10-20', '1', '24000', NULL, 'INSTAGRAM', 'Entregado'),
  (1174, 12, 2, '2025-09-02', '1', '42000', '0', 'instagram', 'Entregado'),
  (1175, 9, 2, '2025-09-27', '1', '42000', '0.05', 'WEB', 'Cancelado'),
  (1176, 3, 7, '07/04/2025', '1', '24000', '0.05', 'whatsapp', 'Entregado '),
  (1177, 13, 2, '2025-09-23', '1', '42000', NULL, 'web', 'Entregado '),
  (1178, 3, 3, '2025-09-15', '1', '78000', NULL, 'Web', 'Entregado'),
  (1179, 14, 9, '02/08/2025', '3', '89000', '0.05', 'Web', 'entregado'),
  (1180, 13, 1, '2025-03-01', '2', '42000', NULL, 'WhatsApp', 'ENTREGADO'),
  (1181, 6, 3, '2025-12-21', '1', '78000', '0.10', 'instagram', 'Entregado'),
  (1182, 14, 5, '2025-02-18', '2', '36000', '0.10', 'WEB', 'cancelado'),
  (1183, 3, 2, '2025-03-19', '2', '42000', NULL, 'WHATSAPP', 'entregado'),
  (1184, 23, 7, '2025-07-22', '2', '24000', '0.05', 'instagram', 'Entregado '),
  (1185, 24, 2, '2025-12-10', '1', '42000', '0.05', 'WhatsApp', 'entregado'),
  (1186, 1, 14, '2025-03-26', '1', '120000', '0', 'web', 'Entregado '),
  (1187, 20, 6, '27/06/2025', '4', '31000', '0', 'whatsapp', 'Entregado '),
  (1188, 13, 7, '10/05/2025', '4', '24000', '0.10', 'Web', 'Entregado'),
  (1189, 18, 1, '2025-05-15', '2', '42000', '0.05', 'WEB', 'entregado'),
  (1190, 6, 2, '2025-02-02', '1', NULL, NULL, 'WhatsApp', 'Entregado '),
  (1191, 21, 7, '12/11/2025', '1', '24000', '0', 'web', 'ENTREGADO'),
  (1192, 6, 8, '09/10/2025', '1', '25000', '0.05', 'INSTAGRAM', 'Entregado '),
  (1193, 18, 1, '2025-08-20', '2', '42000', NULL, 'web', 'Entregado'),
  (1194, 6, 7, '10/12/2025', '2', '24000', NULL, 'WEB', 'Entregado'),
  (1195, 6, 7, '2025-12-09', '2', '24000', NULL, 'web', 'Entregado'),
  (1196, 13, 12, '2025-04-14', '1', '98000', '0.10', 'Instagram', 'ENTREGADO'),
  (1197, 25, 5, '2025-10-10', '3', '36000', '0', 'INSTAGRAM', 'entregado'),
  (1198, 20, 9, '21/03/2025', '1', '89000', '0.10', 'Instagram', 'CANCELADO'),
  (1199, 18, 7, '2025-05-12', '1', '24000', '0', 'Web', 'ENTREGADO'),
  (1200, 18, 3, '06/05/2025', '1', '78000', '0.10', 'WEB', 'entregado'),
  (1201, 20, 5, '15/08/2025', '1', '36000', '0', 'instagram', 'ENTREGADO'),
  (1202, 6, 5, '2025-03-20', '4', '36000', '0', 'Web', 'Entregado'),
  (1203, 20, 12, '2025-10-07', '1', '98000', '0', 'whatsapp', 'Entregado '),
  (1204, 6, 1, '2025-06-19', '3', '42000', NULL, NULL, 'entregado'),
  (1205, 12, 5, '2025-09-03', '4', NULL, '0.10', 'instagram', 'cancelado'),
  (1206, 8, 4, '2025-07-08', '1', '64000', '0', NULL, 'ENTREGADO'),
  (1207, 16, 7, '2025-06-07', '3', '24000', '0.05', 'whatsapp', 'ENTREGADO'),
  (1208, 18, 2, '22/04/2025', '3', NULL, NULL, 'web', 'Entregado '),
  (1209, 9, 7, '18/12/2025', '2', '24000', NULL, 'Web', 'Entregado'),
  (1210, 9, 7, '2025-12-18', '2', '24000', NULL, 'whatsapp', 'entregado'),
  (1211, 11, 1, '2025-01-13', '1', '42000', '0', 'whatsapp', 'Entregado'),
  (1212, 6, 12, '2025-12-18', '1', '98000', NULL, 'Instagram', 'cancelado'),
  (1213, 20, 2, '2025-04-06', '3', '42000', '0.05', 'Web', 'entregado'),
  (1214, 5, 2, '2025-07-25', '4', '42000', '0', 'Instagram', 'entregado'),
  (1215, 9, 4, '02/09/2025', '2', '64000', '0.10', 'Instagram', 'ENTREGADO'),
  (1216, 6, 5, '24/06/2025', '1', '36000', NULL, 'whatsapp', 'Entregado'),
  (1217, 18, 5, '2025-04-17', '3', '36000', '0', NULL, 'Entregado '),
  (1218, 24, 6, '09/08/2025', '1', '31000', '0', 'Web', 'Entregado'),
  (1219, 13, 8, '2025-07-05', '2', '25000', '0.10', 'whatsapp', 'ENTREGADO'),
  (1220, 19, 6, '10/04/2025', '1', '31000', '0', 'WhatsApp', 'Entregado '),
  (1221, 11, 3, '16/12/2025', '1', '78000', NULL, 'Instagram', 'ENTREGADO'),
  (1222, 15, 1, '2025-12-27', '2', '42000', '0.05', 'instagram', 'Cancelado '),
  (1223, 18, 12, '10/12/2025', '1', '98000', '0.05', 'Web', 'ENTREGADO'),
  (1224, 11, 4, '2025-04-06', '2', '64000', '0', 'whatsapp', 'Cancelado '),
  (1225, 8, 14, '16/12/2025', '4', '120000', '0.10', 'Instagram', 'Entregado '),
  (1226, 1, 14, '2025-12-27', '2', NULL, NULL, 'WEB', 'ENTREGADO'),
  (1227, 13, 3, '2025-06-15', '1', '78000', '0.05', 'WEB', 'Entregado'),
  (1228, 6, 2, '2025-10-04', '1', '42000', NULL, 'instagram', 'Entregado'),
  (1229, 13, 7, '2025-08-05', '1', '24000', NULL, NULL, 'Entregado'),
  (1230, 12, 1, '2025-04-25', '2', '42000', '0.10', 'WEB', 'Entregado '),
  (1231, 10, 11, '2025-12-15', '1', '165000', NULL, 'Instagram', 'ENTREGADO'),
  (1232, 20, 5, '2025-01-28', '2', '36000', '0.10', 'WEB', 'ENTREGADO'),
  (1233, 18, 12, '2025-03-23', '3', '98000', NULL, 'WHATSAPP', 'Entregado'),
  (1234, 8, 3, '19/12/2025', '1', '78000', NULL, 'INSTAGRAM', 'Entregado'),
  (1235, 6, 8, '2025-05-26', '2', '25000', '0.10', NULL, 'Entregado'),
  (1236, 3, 7, '2025-12-13', '2', '24000', NULL, 'INSTAGRAM', 'Entregado '),
  (1237, 23, 2, '2025-04-10', '2', '42000', '0.10', 'Web', 'ENTREGADO'),
  (1238, 21, 3, '2025-01-23', '1', '78000', '0', 'Web', 'ENTREGADO'),
  (1239, 16, 4, '05/03/2025', '3', '64000', NULL, NULL, 'entregado'),
  (1240, 12, 12, '2025-10-12', '1', '98000', NULL, 'instagram', 'Cancelado'),
  (1241, 4, 5, '2025-12-24', '3', '36000', NULL, 'WEB', 'entregado'),
  (1242, 20, 3, '2025-03-01', '4', NULL, NULL, 'web', 'Entregado'),
  (1243, 4, 1, '2025-09-24', '1', '42000', '0', 'whatsapp', 'entregado'),
  (1244, 1, 5, '2025-04-01', '1', '36000', '0', 'instagram', 'CANCELADO'),
  (1245, 13, 6, '2025-08-05', '1', '31000', '0.05', 'Instagram', 'CANCELADO'),
  (1246, 1, 2, '04/06/2025', '1', '42000', NULL, 'WEB', 'ENTREGADO'),
  (1247, 13, 4, '20/09/2025', '1', '64000', NULL, 'Instagram', 'Entregado '),
  (1248, 1, 7, '2025-09-12', '1', '24000', '0.05', 'WEB', 'Entregado'),
  (1249, 1, 7, '2025-10-12', '2', '24000', NULL, 'INSTAGRAM', 'Entregado'),
  (1250, 7, 1, '2025-04-10', '1', '42000', NULL, 'WEB', 'ENTREGADO'),
  (1251, 18, 12, '19/04/2025', '3', '98000', '0', 'Web', 'Entregado'),
  (1252, 18, 5, '2025-11-27', '2', '36000', '0.05', 'web', 'entregado'),
  (1253, 6, 12, '2025-07-04', '1', '98000', '0.05', 'whatsapp', 'Entregado '),
  (1254, 20, 7, '2025-12-25', '1', '24000', '0.10', 'Web', 'entregado'),
  (1255, 3, 3, '06/01/2025', '3', '78000', '0.05', 'INSTAGRAM', 'Cancelado '),
  (1256, 18, 3, '2025-04-04', '1', '78000', NULL, 'web', 'Entregado'),
  (1257, 9, 1, '2025-09-26', '1', '42000', NULL, 'INSTAGRAM', 'entregado'),
  (1258, 9, 7, '2025-11-25', '3', '24000', '0.05', 'WEB', 'Entregado '),
  (1259, 3, 14, '20/11/2025', '1', NULL, NULL, 'instagram', 'Entregado '),
  (1260, 18, 1, '2025-04-23', '1', '42000', '0.05', NULL, 'entregado'),
  (1261, 4, 3, '2025-12-23', '1', '78000', '0.05', 'Instagram', 'ENTREGADO'),
  (1262, 18, 4, '01/10/2025', '2', NULL, '0.10', 'INSTAGRAM', 'Entregado'),
  (1263, 12, 9, '01/03/2025', '1', '89000', NULL, 'web', 'ENTREGADO'),
  (1264, 23, 5, '2025-10-18', '1', '36000', '0.05', 'WhatsApp', 'ENTREGADO'),
  (1265, 3, 2, '28/07/2025', '2', '42000', NULL, 'Instagram', 'Entregado'),
  (1266, 13, 1, '2025-12-10', '2', '42000', '0', 'web', 'ENTREGADO'),
  (1267, 9, 2, '2025-12-25', '1', '42000', NULL, 'instagram', 'ENTREGADO'),
  (1268, 18, 1, '2025-10-20', NULL, '42000', NULL, 'WEB', 'Entregado '),
  (1269, 9, 12, '2025-07-03', '2', '98000', '0.10', 'whatsapp', 'ENTREGADO'),
  (1270, 6, 7, '2025-11-17', '1', '24000', NULL, 'WEB', 'entregado'),
  (1271, 24, 1, '13/12/2025', '3', '42000', NULL, 'WHATSAPP', 'entregado'),
  (1272, 22, 5, '2025-12-06', '1', '36000', NULL, 'Web', 'entregado'),
  (1273, 13, 8, '2025-04-21', '1', '25000', NULL, 'web', 'entregado'),
  (1274, 22, 8, '2025-08-16', '1', '25000', NULL, 'WEB', 'Entregado'),
  (1275, 21, 2, '2025-09-22', '1', '42000', '0.10', 'instagram', 'Cancelado'),
  (1276, 13, 1, '28/12/2025', '2', '42000', NULL, 'Instagram', 'entregado'),
  (1277, 13, 8, '2025-08-22', '3', '25000', NULL, 'Instagram', 'ENTREGADO'),
  (1278, 20, 7, '2025-08-06', NULL, '24000', NULL, 'web', 'ENTREGADO'),
  (1279, 11, 3, '2025-10-12', '1', '78000', '0.10', 'WHATSAPP', 'ENTREGADO'),
  (1280, 5, 8, '2025-11-17', '1', '25000', NULL, 'instagram', 'entregado'),
  (1281, 3, 9, '2025-07-09', '1', '89000', '0.05', 'Web', 'Entregado'),
  (1282, 6, 1, '24/07/2025', '1', '42000', NULL, 'instagram', 'Cancelado '),
  (1283, 13, 12, '28/12/2025', '3', NULL, '0.05', 'INSTAGRAM', 'cancelado'),
  (1284, 13, 4, '2025-02-06', '2', '64000', NULL, 'web', 'cancelado'),
  (1285, 6, 5, '2025-05-21', '1', '36000', '0.10', 'Web', 'Entregado '),
  (1286, 8, 5, '2025-12-03', '1', '36000', NULL, 'INSTAGRAM', 'Entregado '),
  (1287, 11, 1, '2025-05-25', '2', '42000', NULL, 'WhatsApp', 'ENTREGADO'),
  (1288, 12, 2, '2025-10-18', '1', '42000', '0', 'INSTAGRAM', 'Entregado'),
  (1289, 6, 12, '2025-08-21', '1', '98000', NULL, 'instagram', 'Entregado'),
  (1290, 11, 4, '2025-03-05', '1', '64000', NULL, 'WEB', 'Entregado'),
  (1291, 21, 1, '2025-09-23', '3', '42000', NULL, 'instagram', 'ENTREGADO'),
  (1292, 18, 4, '2025-10-23', '1', '64000', '0.05', 'web', 'entregado'),
  (1293, 3, 8, '13/01/2025', '1', '25000', NULL, 'WHATSAPP', 'ENTREGADO'),
  (1294, 6, 9, '2025-12-27', '1', '89000', NULL, 'WEB', 'Entregado '),
  (1295, 20, 10, '2025-12-16', '1', '115000', NULL, 'instagram', 'entregado'),
  (1296, 1, 2, '28/11/2025', '1', '42000', NULL, 'instagram', 'cancelado'),
  (1297, 9, 6, '21/08/2025', '1', '31000', '0', 'Instagram', 'Entregado '),
  (1298, 18, 12, '2025-12-25', '1', NULL, '0', 'WHATSAPP', 'entregado'),
  (1299, 2, 7, '2025-02-28', '2', '24000', NULL, 'web', 'Entregado '),
  (1300, 6, 3, '09/09/2025', '1', '78000', NULL, 'web', 'entregado'),
  (1301, 21, 12, '12/07/2025', '1', '98000', NULL, 'Web', 'Entregado '),
  (1302, 15, 5, '2025-09-28', '1', '36000', '0', 'web', 'Entregado'),
  (1303, 10, 12, '2025-03-16', '1', '98000', NULL, 'web', 'Entregado'),
  (1304, 6, 1, '2025-03-15', '1', '42000', '0', NULL, 'Entregado '),
  (1305, 3, 5, '2025-11-03', '2', '36000', NULL, 'WHATSAPP', 'entregado'),
  (1306, 20, 7, '02/03/2025', '2', NULL, '0', 'Web', 'ENTREGADO'),
  (1307, 4, 2, '2025-10-02', '1', '42000', NULL, 'WhatsApp', 'ENTREGADO'),
  (1308, 14, 1, '2025-09-17', '2', '42000', NULL, 'instagram', 'Entregado'),
  (1309, 23, 7, '2025-12-12', '1', '24000', '0', 'WEB', 'Entregado '),
  (1310, 25, 5, '15/08/2025', '3', '36000', '0.10', 'Web', 'Entregado '),
  (1311, 6, 7, '2025-05-11', '2', '24000', NULL, 'Web', 'entregado'),
  (1312, 23, 1, '03/11/2025', '3', '42000', NULL, 'INSTAGRAM', 'CANCELADO'),
  (1313, 18, 1, '27/09/2025', '2', '42000', '0.10', 'instagram', 'Cancelado'),
  (1314, 18, 5, '2025-07-15', '2', '36000', NULL, 'instagram', 'Entregado'),
  (1315, 9, 1, '2025-03-20', '2', '42000', NULL, 'whatsapp', 'Entregado '),
  (1316, 4, 14, '2025-10-23', '2', '120000', NULL, 'INSTAGRAM', 'Entregado '),
  (1317, 16, 2, '2025-05-21', '3', '42000', NULL, 'WhatsApp', 'entregado'),
  (1318, 18, 5, '2025-05-16', '1', '36000', NULL, 'whatsapp', 'ENTREGADO'),
  (1319, 13, 13, '2025-12-12', '2', '135000', '0', 'instagram', 'ENTREGADO'),
  (1320, 10, 4, '2025-07-05', '2', '64000', NULL, 'Web', 'Entregado '),
  (1011, 13, 7, '2025-11-08', '1', '24000', NULL, 'Instagram', 'ENTREGADO'),
  (1058, 3, 1, '2025-03-05', '2', NULL, '0.10', 'Web', 'Entregado '),
  (1141, 20, 9, '2025-11-07', '1', '89000', '0.05', 'instagram', 'entregado');


/* =====================================================================
   SECCIÓN 3 · TABLAS DEFINITIVAS (MODELO LIMPIO)
   Modelo: clientes (1) ---< pedidos >--- (1) productos
   Decisiones de tipos:
     - NUMERIC(12,2) para dinero: es exacto. FLOAT/REAL generan errores de
       redondeo (0.1 + 0.2 = 0.30000000000000004) inaceptables en ventas.
     - DATE para fechas: habilita DATE_TRUNC, EXTRACT, TO_CHAR y comparar
       rangos. Una fecha guardada como texto no se puede agrupar por mes.
     - CHECK: la base de datos rechaza valores imposibles (cantidad 0,
       descuento del 150 %) en lugar de confiar en que nadie se equivoque.
   ===================================================================== */
CREATE TABLE clientes (
    cliente_id      INTEGER       PRIMARY KEY,
    nombre          VARCHAR(100)  NOT NULL,
    email           VARCHAR(150)  NOT NULL UNIQUE,
    ciudad          VARCHAR(60)   NOT NULL DEFAULT 'Sin dato',
    fecha_registro  DATE          NOT NULL
);

CREATE TABLE productos (
    producto_id     INTEGER       PRIMARY KEY,
    nombre          VARCHAR(100)  NOT NULL,
    categoria       VARCHAR(50)   NOT NULL,
    precio_lista    NUMERIC(12,2) NOT NULL CHECK (precio_lista > 0)
);

CREATE TABLE pedidos (
    pedido_id       INTEGER       PRIMARY KEY,
    cliente_id      INTEGER       NOT NULL REFERENCES clientes (cliente_id),
    producto_id     INTEGER       NOT NULL REFERENCES productos (producto_id),
    fecha_pedido    DATE          NOT NULL,
    cantidad        INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario > 0),
    descuento       NUMERIC(4,2)  NOT NULL DEFAULT 0 CHECK (descuento BETWEEN 0 AND 1),
    canal           VARCHAR(20)   NOT NULL,
    estado          VARCHAR(20)   NOT NULL CHECK (estado IN ('Entregado', 'Cancelado')),
    -- Columna calculada: PostgreSQL la mantiene sola. Evita que cada
    -- consulta repita (y quizá equivoque) la fórmula del ingreso neto.
    monto_neto      NUMERIC(14,2) GENERATED ALWAYS AS
                    (ROUND(cantidad * precio_unitario * (1 - descuento), 2)) STORED
);

-- Índices SOLO en las columnas que usamos en JOIN y filtros por fecha.
-- Indexar todo ralentiza las cargas sin beneficio (trampa del analista junior).
CREATE INDEX idx_pedidos_cliente  ON pedidos (cliente_id);
CREATE INDEX idx_pedidos_producto ON pedidos (producto_id);
CREATE INDEX idx_pedidos_fecha    ON pedidos (fecha_pedido);


/* =====================================================================
   SECCIÓN 4 · LIMPIEZA Y TRANSFORMACIÓN  (staging -> definitivas)
   Regla general: cada decisión sobre datos faltantes queda escrita aquí,
   para que cualquier persona pueda auditarla o cambiarla.
   ===================================================================== */

-- 4.1 CLIENTES ---------------------------------------------------------
-- DISTINCT ON elimina los 2 clientes duplicados: nos quedamos con una
-- sola fila por cliente_id (los duplicados son copias exactas).
INSERT INTO clientes (cliente_id, nombre, email, ciudad, fecha_registro)
SELECT DISTINCT ON (cliente_id)
       cliente_id,
       -- TRIM quita espacios sobrantes; INITCAP deja "Nombre Apellido"
       -- para que los reportes se vean profesionales.
       INITCAP(TRIM(nombre)),
       -- Los emails se comparan en minúscula: 'ANA@X.COM' y 'ana@x.com'
       -- son la misma persona y la restricción UNIQUE debe detectarlo.
       LOWER(TRIM(email)),
       -- Ciudad: NULLIF convierte el texto vacío '' en NULL y COALESCE
       -- reemplaza cualquier NULL por 'Sin dato'. Así esos clientes NO
       -- desaparecen del análisis por ciudad, quedan visibles como grupo.
       COALESCE(
           CASE LOWER(TRIM(ciudad))
               WHEN 'bogota' THEN 'Bogotá'            -- unificamos la tilde
               WHEN 'bogotá' THEN 'Bogotá'
               ELSE INITCAP(NULLIF(TRIM(ciudad), ''))
           END,
           'Sin dato'),
       -- Fechas en dos formatos: detectamos el patrón con una expresión
       -- regular y aplicamos la máscara correcta en cada caso.
       CASE
           WHEN fecha_registro ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(fecha_registro, 'YYYY-MM-DD')
           WHEN fecha_registro ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(fecha_registro, 'DD/MM/YYYY')
       END
FROM   stg_clientes
ORDER  BY cliente_id;

-- 4.2 PRODUCTOS --------------------------------------------------------
-- Precio faltante en catálogo (columna crítica): en vez de inventar un
-- número o poner 0 (que hundiría cualquier promedio), lo imputamos con
-- la MEDIANA del precio realmente cobrado en los pedidos de ese producto.
-- Usamos mediana y no promedio porque no se deja arrastrar por valores
-- atípicos (por ejemplo, una venta con precio especial).
WITH precio_cobrado AS (
    SELECT producto_id,
           PERCENTILE_CONT(0.5) WITHIN GROUP (
               ORDER BY NULLIF(TRIM(precio_unitario), '')::NUMERIC
           ) AS mediana_cobrada
    FROM   stg_pedidos
    GROUP  BY producto_id
)
INSERT INTO productos (producto_id, nombre, categoria, precio_lista)
SELECT p.producto_id,
       TRIM(p.nombre),
       -- Estandarizamos la categoría: pasamos a minúscula, quitamos
       -- tildes y espacios, y mapeamos cada variante a un único nombre.
       -- Sin esto, "Café en grano" y "CAFÉ EN GRANO " serían 2 categorías.
       CASE TRANSLATE(LOWER(TRIM(p.categoria)), 'áéíóú', 'aeiou')
           WHEN 'cafe en grano'  THEN 'Café en grano'
           WHEN 'cafe molido'    THEN 'Café molido'
           WHEN 'capsulas'       THEN 'Cápsulas'
           WHEN 'accesorios'     THEN 'Accesorios'
           WHEN 'kits y regalos' THEN 'Kits y regalos'
           WHEN 'suscripciones'  THEN 'Suscripciones'
           ELSE 'Otros'
       END,
       COALESCE(NULLIF(TRIM(p.precio_lista), '')::NUMERIC,
                ROUND(pc.mediana_cobrada::NUMERIC, 2))
FROM   stg_productos p
LEFT   JOIN precio_cobrado pc ON pc.producto_id = p.producto_id
ORDER  BY p.producto_id;

-- 4.3 PEDIDOS ----------------------------------------------------------
-- DISTINCT ON (pedido_id) elimina los 3 pedidos cargados dos veces; sin
-- esto, esas ventas se sumarían doble e inflarían los ingresos.
INSERT INTO pedidos (pedido_id, cliente_id, producto_id, fecha_pedido,
                     cantidad, precio_unitario, descuento, canal, estado)
SELECT DISTINCT ON (s.pedido_id)
       s.pedido_id,
       s.cliente_id,
       s.producto_id,
       CASE
           WHEN s.fecha_pedido ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(s.fecha_pedido, 'YYYY-MM-DD')
           WHEN s.fecha_pedido ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(s.fecha_pedido, 'DD/MM/YYYY')
       END,
       -- Cantidad vacía: si existe el pedido, se vendió al menos 1 unidad.
       -- Asumir 1 es la opción más conservadora (no infla ingresos).
       COALESCE(NULLIF(TRIM(s.cantidad), '')::INTEGER, 1),
       -- Precio unitario vacío (columna crítica): usamos el precio de
       -- lista ya limpio del producto, que es lo que el cliente pagaría.
       COALESCE(NULLIF(TRIM(s.precio_unitario), '')::NUMERIC, p.precio_lista),
       -- Descuento vacío = no hubo descuento (0). Si dejáramos NULL, la
       -- fórmula del monto neto devolvería NULL y el pedido "valdría" nada.
       COALESCE(NULLIF(TRIM(s.descuento), '')::NUMERIC, 0),
       -- Canal: unificamos mayúsculas y respetamos la marca "WhatsApp".
       COALESCE(
           CASE LOWER(TRIM(s.canal))
               WHEN 'web'       THEN 'Web'
               WHEN 'whatsapp'  THEN 'WhatsApp'
               WHEN 'instagram' THEN 'Instagram'
           END,
           'Sin dato'),
       INITCAP(TRIM(s.estado))
FROM   stg_pedidos s
JOIN   productos  p ON p.producto_id = s.producto_id
ORDER  BY s.pedido_id;


/* =====================================================================
   SECCIÓN 5 · VERIFICACIÓN DE LA CARGA
   Por qué: comprobar que no perdimos ni duplicamos filas al limpiar.
   Resultado esperado: clientes 27 -> 25 · productos 15 -> 15 ·
   pedidos 323 -> 320 (se eliminan exactamente los duplicados).
   ===================================================================== */
SELECT 'clientes'  AS tabla, (SELECT COUNT(*) FROM stg_clientes)  AS filas_crudas, (SELECT COUNT(*) FROM clientes)  AS filas_limpias
UNION ALL
SELECT 'productos',          (SELECT COUNT(*) FROM stg_productos),                (SELECT COUNT(*) FROM productos)
UNION ALL
SELECT 'pedidos',            (SELECT COUNT(*) FROM stg_pedidos),                  (SELECT COUNT(*) FROM pedidos);
