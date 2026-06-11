-- ============================================================
-- SISTEMA DE GESTIÓN HOTELERA - hotel_db
-- Normalizado hasta 3FN
-- Compatible con MySQL 8.0+
-- ============================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";
SET FOREIGN_KEY_CHECKS = 0;

-- ------------------------------------------------------------
-- 1. CREAR Y USAR BASE DE DATOS
-- ------------------------------------------------------------
DROP DATABASE IF EXISTS hotel_db;
CREATE DATABASE hotel_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE hotel_db;

-- ------------------------------------------------------------
-- 2. TABLAS (orden respetando FK)
-- ------------------------------------------------------------

-- 2.1 tipo_habitacion
CREATE TABLE tipo_habitacion (
    id          INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nombre      VARCHAR(50)     NOT NULL,
    descripcion TEXT,
    capacidad   TINYINT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    UNIQUE KEY uq_tipo_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.2 habitacion
CREATE TABLE habitacion (
    id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    numero          VARCHAR(10)     NOT NULL,
    id_tipo         INT UNSIGNED    NOT NULL,
    tarifa_noche    DECIMAL(10,2)   NOT NULL,
    estado          ENUM('disponible','ocupada','reservada','mantenimiento')
                    NOT NULL DEFAULT 'disponible',
    descripcion     TEXT,
    PRIMARY KEY (id),
    UNIQUE KEY uq_habitacion_numero (numero),
    CONSTRAINT fk_habitacion_tipo
        FOREIGN KEY (id_tipo) REFERENCES tipo_habitacion(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_tarifa CHECK (tarifa_noche > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.3 huesped
CREATE TABLE huesped (
    id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(100)    NOT NULL,
    tipo_documento  ENUM('CC','CE','PA','NIT') NOT NULL DEFAULT 'CC',
    num_documento   VARCHAR(20)     NOT NULL,
    telefono        VARCHAR(20),
    correo          VARCHAR(120),
    direccion       VARCHAR(200),
    fecha_registro  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_huesped_documento (tipo_documento, num_documento),
    CONSTRAINT chk_correo CHECK (correo IS NULL OR correo LIKE '%_@_%._%')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.4 reserva
CREATE TABLE reserva (
    id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    id_huesped      INT UNSIGNED    NOT NULL,
    id_habitacion   INT UNSIGNED    NOT NULL,
    fecha_entrada   DATE            NOT NULL,
    fecha_salida    DATE            NOT NULL,
    estado          ENUM('pendiente','confirmada','check_in','check_out','cancelada')
                    NOT NULL DEFAULT 'pendiente',
    noches          SMALLINT UNSIGNED GENERATED ALWAYS AS
                    (DATEDIFF(fecha_salida, fecha_entrada)) STORED,
    total_hospedaje DECIMAL(12,2)   DEFAULT 0.00,
    total_servicios DECIMAL(12,2)   DEFAULT 0.00,
    total_general   DECIMAL(12,2)   GENERATED ALWAYS AS
                    (total_hospedaje + total_servicios) STORED,
    observaciones   TEXT,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_reserva_huesped
        FOREIGN KEY (id_huesped) REFERENCES huesped(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_reserva_habitacion
        FOREIGN KEY (id_habitacion) REFERENCES habitacion(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_fechas CHECK (fecha_salida > fecha_entrada)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.5 acompanante
CREATE TABLE acompanante (
    id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(100)    NOT NULL,
    tipo_documento  ENUM('CC','CE','PA','NIT') NOT NULL DEFAULT 'CC',
    num_documento   VARCHAR(20)     NOT NULL,
    telefono        VARCHAR(20),
    PRIMARY KEY (id),
    UNIQUE KEY uq_acomp_documento (tipo_documento, num_documento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.6 reserva_acompanante (tabla pivote N:M)
CREATE TABLE reserva_acompanante (
    id_reserva      INT UNSIGNED    NOT NULL,
    id_acompanante  INT UNSIGNED    NOT NULL,
    PRIMARY KEY (id_reserva, id_acompanante),
    CONSTRAINT fk_ra_reserva
        FOREIGN KEY (id_reserva) REFERENCES reserva(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ra_acompanante
        FOREIGN KEY (id_acompanante) REFERENCES acompanante(id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.7 servicio
CREATE TABLE servicio (
    id          INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nombre      VARCHAR(80)     NOT NULL,
    descripcion TEXT,
    precio      DECIMAL(10,2)   NOT NULL,
    activo      TINYINT(1)      NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    UNIQUE KEY uq_servicio_nombre (nombre),
    CONSTRAINT chk_precio_servicio CHECK (precio >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.8 consumo_servicio
CREATE TABLE consumo_servicio (
    id          INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    id_reserva  INT UNSIGNED    NOT NULL,
    id_servicio INT UNSIGNED    NOT NULL,
    cantidad    SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    precio_unit DECIMAL(10,2)   NOT NULL,
    subtotal    DECIMAL(12,2)   GENERATED ALWAYS AS (cantidad * precio_unit) STORED,
    fecha       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notas       VARCHAR(200),
    PRIMARY KEY (id),
    CONSTRAINT fk_cs_reserva
        FOREIGN KEY (id_reserva) REFERENCES reserva(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cs_servicio
        FOREIGN KEY (id_servicio) REFERENCES servicio(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_cantidad CHECK (cantidad > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 3. ÍNDICES ADICIONALES
-- ------------------------------------------------------------
CREATE INDEX idx_habitacion_estado    ON habitacion(estado);
CREATE INDEX idx_habitacion_tipo      ON habitacion(id_tipo);
CREATE INDEX idx_reserva_fechas       ON reserva(fecha_entrada, fecha_salida);
CREATE INDEX idx_reserva_estado       ON reserva(estado);
CREATE INDEX idx_reserva_habitacion   ON reserva(id_habitacion);
CREATE INDEX idx_reserva_huesped      ON reserva(id_huesped);
CREATE INDEX idx_consumo_reserva      ON consumo_servicio(id_reserva);
CREATE INDEX idx_consumo_fecha        ON consumo_servicio(fecha);

-- ------------------------------------------------------------
-- 4. PROCEDIMIENTOS ALMACENADOS
-- ------------------------------------------------------------

DELIMITER $$

-- 4.1 Verificar disponibilidad de habitación
CREATE PROCEDURE sp_verificar_disponibilidad(
    IN p_id_habitacion  INT UNSIGNED,
    IN p_fecha_entrada  DATE,
    IN p_fecha_salida   DATE,
    IN p_excluir_reserva INT UNSIGNED,   -- 0 si es nueva reserva
    OUT p_disponible    TINYINT
)
BEGIN
    DECLARE v_count INT DEFAULT 0;
    SELECT COUNT(*) INTO v_count
    FROM reserva
    WHERE id_habitacion = p_id_habitacion
      AND estado NOT IN ('cancelada','check_out')
      AND id <> IFNULL(p_excluir_reserva, 0)
      AND fecha_entrada < p_fecha_salida
      AND fecha_salida  > p_fecha_entrada;
    SET p_disponible = IF(v_count = 0, 1, 0);
END$$

-- 4.2 Realizar Check-In
CREATE PROCEDURE sp_check_in(IN p_id_reserva INT UNSIGNED)
BEGIN
    DECLARE v_id_hab INT UNSIGNED;
    DECLARE v_estado VARCHAR(20);

    SELECT id_habitacion, estado INTO v_id_hab, v_estado
    FROM reserva WHERE id = p_id_reserva;

    IF v_estado NOT IN ('pendiente','confirmada') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La reserva no está en estado válido para Check-In';
    END IF;

    UPDATE reserva    SET estado = 'check_in'  WHERE id = p_id_reserva;
    UPDATE habitacion SET estado = 'ocupada'   WHERE id = v_id_hab;
END$$

-- 4.3 Realizar Check-Out
CREATE PROCEDURE sp_check_out(IN p_id_reserva INT UNSIGNED)
BEGIN
    DECLARE v_id_hab        INT UNSIGNED;
    DECLARE v_noches        SMALLINT UNSIGNED;
    DECLARE v_tarifa        DECIMAL(10,2);
    DECLARE v_total_hosp    DECIMAL(12,2);
    DECLARE v_total_serv    DECIMAL(12,2);

    SELECT r.id_habitacion, r.noches, h.tarifa_noche
    INTO v_id_hab, v_noches, v_tarifa
    FROM reserva r
    JOIN habitacion h ON h.id = r.id_habitacion
    WHERE r.id = p_id_reserva;

    SET v_total_hosp = v_noches * v_tarifa;

    SELECT IFNULL(SUM(subtotal), 0) INTO v_total_serv
    FROM consumo_servicio WHERE id_reserva = p_id_reserva;

    UPDATE reserva
    SET estado          = 'check_out',
        total_hospedaje = v_total_hosp,
        total_servicios = v_total_serv
    WHERE id = p_id_reserva;

    UPDATE habitacion SET estado = 'disponible' WHERE id = v_id_hab;
END$$

-- 4.4 Reporte de ocupación por rango de fechas
CREATE PROCEDURE sp_reporte_ocupacion(
    IN p_fecha_inicio DATE,
    IN p_fecha_fin    DATE
)
BEGIN
    SELECT
        h.numero,
        th.nombre AS tipo,
        h.tarifa_noche,
        COUNT(r.id) AS total_reservas,
        SUM(r.noches) AS total_noches,
        SUM(r.total_hospedaje) AS ingresos_hospedaje
    FROM habitacion h
    JOIN tipo_habitacion th ON th.id = h.id_tipo
    LEFT JOIN reserva r
        ON r.id_habitacion = h.id
        AND r.fecha_entrada >= p_fecha_inicio
        AND r.fecha_salida  <= p_fecha_fin
        AND r.estado NOT IN ('cancelada')
    GROUP BY h.id, h.numero, th.nombre, h.tarifa_noche
    ORDER BY h.numero;
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- 5. TRIGGERS
-- ------------------------------------------------------------

DELIMITER $$

-- 5.1 Al confirmar reserva → marcar habitación como 'reservada'
CREATE TRIGGER trg_reserva_confirmada
AFTER UPDATE ON reserva
FOR EACH ROW
BEGIN
    IF NEW.estado = 'confirmada' AND OLD.estado <> 'confirmada' THEN
        UPDATE habitacion SET estado = 'reservada' WHERE id = NEW.id_habitacion;
    END IF;
    IF NEW.estado = 'cancelada' AND OLD.estado <> 'cancelada' THEN
        UPDATE habitacion SET estado = 'disponible' WHERE id = NEW.id_habitacion;
    END IF;
END$$

-- 5.2 Al insertar reserva nueva → si estado es confirmada, marcar reservada
CREATE TRIGGER trg_reserva_insert
AFTER INSERT ON reserva
FOR EACH ROW
BEGIN
    IF NEW.estado = 'confirmada' THEN
        UPDATE habitacion SET estado = 'reservada' WHERE id = NEW.id_habitacion;
    END IF;
END$$

-- 5.3 Recalcular total_servicios en reserva al insertar consumo
CREATE TRIGGER trg_consumo_insert
AFTER INSERT ON consumo_servicio
FOR EACH ROW
BEGIN
    UPDATE reserva
    SET total_servicios = (
        SELECT IFNULL(SUM(subtotal),0) FROM consumo_servicio WHERE id_reserva = NEW.id_reserva
    )
    WHERE id = NEW.id_reserva;
END$$

-- 5.4 Recalcular total_servicios al eliminar consumo
CREATE TRIGGER trg_consumo_delete
AFTER DELETE ON consumo_servicio
FOR EACH ROW
BEGIN
    UPDATE reserva
    SET total_servicios = (
        SELECT IFNULL(SUM(subtotal),0) FROM consumo_servicio WHERE id_reserva = OLD.id_reserva
    )
    WHERE id = OLD.id_reserva;
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- 6. DATOS DE PRUEBA
-- ------------------------------------------------------------

-- Tipos de habitación
INSERT INTO tipo_habitacion (nombre, descripcion, capacidad) VALUES
('Sencilla',  'Habitación individual con cama sencilla, baño privado y TV.',        1),
('Doble',     'Habitación con cama doble o dos camas, baño privado, TV y minibar.', 2),
('Suite',     'Suite de lujo con sala, jacuzzi, minibar y vista panorámica.',       4);

-- Habitaciones (20)
INSERT INTO habitacion (numero, id_tipo, tarifa_noche, estado, descripcion) VALUES
('101', 1, 120000, 'disponible', 'Piso 1 vista interior'),
('102', 1, 120000, 'disponible', 'Piso 1 vista interior'),
('103', 1, 130000, 'disponible', 'Piso 1 vista jardín'),
('104', 2, 180000, 'disponible', 'Piso 1 doble estándar'),
('105', 2, 180000, 'disponible', 'Piso 1 doble estándar'),
('201', 1, 125000, 'disponible', 'Piso 2 vista interior'),
('202', 1, 125000, 'disponible', 'Piso 2 vista interior'),
('203', 2, 190000, 'disponible', 'Piso 2 doble premium'),
('204', 2, 190000, 'disponible', 'Piso 2 doble premium'),
('205', 3, 320000, 'disponible', 'Suite ejecutiva piso 2'),
('301', 1, 130000, 'disponible', 'Piso 3 vista calle'),
('302', 1, 130000, 'disponible', 'Piso 3 vista calle'),
('303', 2, 195000, 'disponible', 'Piso 3 doble lujo'),
('304', 2, 195000, 'disponible', 'Piso 3 doble lujo'),
('305', 3, 350000, 'disponible', 'Suite panorámica piso 3'),
('401', 2, 200000, 'disponible', 'Piso 4 doble deluxe'),
('402', 2, 200000, 'disponible', 'Piso 4 doble deluxe'),
('403', 3, 380000, 'disponible', 'Suite presidencial'),
('404', 1, 135000, 'mantenimiento', 'En remodelación'),
('405', 2, 185000, 'disponible', 'Piso 4 doble estándar');

-- Huéspedes (15)
INSERT INTO huesped (nombre, tipo_documento, num_documento, telefono, correo, direccion) VALUES
('Carlos Andrés Gómez Ruiz',     'CC', '1098765432', '3101234567', 'carlos.gomez@email.com',   'Calle 45 #23-10, Bucaramanga'),
('María Fernanda López Pérez',   'CC', '1098234567', '3202345678', 'mfernanda@gmail.com',       'Carrera 27 #52-18, Medellín'),
('Jorge Luis Martínez Díaz',     'CC', '79876543',   '3003456789', 'jlmartinez@hotmail.com',    'Av 19 #134-11, Bogotá'),
('Ana Lucía Vargas Torres',      'CE', 'CE1234567',  '3124567890', 'anavargas@email.com',       'Calle 10 #5-22, Cali'),
('Pedro Pablo Jiménez Ramos',    'CC', '94567890',   '3205678901', 'pjimenez@company.com',      'Cra 50 #80-40, Barranquilla'),
('Claudia Patricia Silva Mora',  'CC', '52678901',   '3006789012', 'csilva@correo.com',         'Calle 72 #11-22, Bogotá'),
('Roberto Carlos Peña Lozano',   'PA', 'PA789012',   '3107890123', 'rpeña@email.com',           'Carrera 8 #15-30, Cartagena'),
('Isabel Cristina Reyes Mora',   'CC', '1023456789', '3208901234', 'isabelreyes@gmail.com',     'Calle 100 #15-20, Bogotá'),
('Andrés Felipe Castro García',  'CC', '1045678901', '3009012345', 'acastro@correo.co',         'Av El Dorado #68-11, Bogotá'),
('Laura Milena Suárez Ortiz',    'CC', '1056789012', '3160123456', 'lsuarez@email.com',         'Calle 5 #38-42, Manizales'),
('Diego Alejandro Rojas Cruz',   'NIT','900123456-1','6014567890', 'drojas@empresa.com',        'Calle 93 #11B-17, Bogotá'),
('Sandra Liliana Mora Vega',     'CC', '41567890',   '3171234567', 'smora@email.com',           'Cra 3 #10-15, Santa Marta'),
('Camilo Andrés Herrera Peña',   'CC', '1078901234', '3222345678', 'cherrera@gmail.com',        'Calle 40 #30-20, Pereira'),
('Valentina Ríos Gómez',         'CC', '1089012345', '3113456789', 'vrios@correo.com',          'Av Suba #124-56, Bogotá'),
('Mauricio Alberto Pardo Silva', 'CC', '79234567',   '3004567890', 'mpardo@email.com',          'Calle 17 #7-35, Villavicencio');

-- Servicios (5)
INSERT INTO servicio (nombre, descripcion, precio, activo) VALUES
('Restaurante',   'Servicio de alimentos y bebidas en el restaurante del hotel.', 45000,  1),
('Lavandería',    'Lavado y planchado de prendas. Por kg o por prenda.',          15000,  1),
('Minibar',       'Recarga de minibar: bebidas, snacks y confitería.',            25000,  1),
('Parqueadero',   'Parqueadero cubierto 24 horas, por día.',                     20000,  1),
('Transporte',    'Servicio de traslado aeropuerto-hotel o tours locales.',       80000,  1);

-- Reservas (20)
-- Usamos fechas relativas al 2024 para datos coherentes
INSERT INTO reserva (id_huesped, id_habitacion, fecha_entrada, fecha_salida, estado, total_hospedaje, total_servicios, observaciones) VALUES
(1,  1,  '2024-01-05', '2024-01-08', 'check_out',  360000,  45000, 'Cliente frecuente'),
(2,  4,  '2024-01-10', '2024-01-13', 'check_out',  540000,  90000, NULL),
(3,  10, '2024-01-15', '2024-01-18', 'check_out',  960000, 120000, 'Suite ejecutiva'),
(4,  2,  '2024-02-01', '2024-02-03', 'check_out',  240000,  25000, NULL),
(5,  5,  '2024-02-10', '2024-02-14', 'check_out',  720000,  80000, 'Dos noches extra'),
(6,  6,  '2024-02-20', '2024-02-22', 'check_out',  250000,  60000, NULL),
(7,  15, '2024-03-01', '2024-03-05', 'check_out', 1400000, 200000, 'Suite panorámica'),
(8,  3,  '2024-03-10', '2024-03-12', 'check_out',  260000,  30000, NULL),
(9,  7,  '2024-03-15', '2024-03-17', 'check_out',  250000,  45000, NULL),
(10, 8,  '2024-04-01', '2024-04-04', 'check_out',  375000,  90000, NULL),
(11, 18, '2024-04-10', '2024-04-15', 'check_out', 1900000, 320000, 'Presidencial - corporativo'),
(12, 9,  '2024-05-01', '2024-05-03', 'check_out',  380000,  50000, NULL),
(13, 11, '2024-05-10', '2024-05-12', 'check_out',  260000,  25000, NULL),
(14, 12, '2024-05-20', '2024-05-23', 'check_out',  390000,  80000, NULL),
(15, 13, '2024-06-01', '2024-06-04', 'check_out',  585000, 100000, NULL),
(1,  14, '2024-06-15', '2024-06-18', 'check_out',  585000,  75000, 'Segunda visita'),
(2,  16, '2024-07-01', '2024-07-05', 'check_out',  800000, 120000, NULL),
(3,  10, '2024-08-01', '2024-08-04', 'check_in',   960000,  80000, 'Check-in activo'),
(4,  4,  '2024-08-10', '2024-08-14', 'confirmada',       0,      0, NULL),
(5,  5,  '2024-09-01', '2024-09-03', 'pendiente',        0,      0, 'Walk-in programado');

-- Actualizar estado habitaciones según reservas activas
UPDATE habitacion SET estado = 'ocupada'   WHERE id = 10;  -- reserva 18 check_in
UPDATE habitacion SET estado = 'reservada' WHERE id = 4;   -- reserva 19 confirmada
UPDATE habitacion SET estado = 'reservada' WHERE id = 5;   -- reserva 20 pendiente

-- Acompañantes (10)
INSERT INTO acompanante (nombre, tipo_documento, num_documento, telefono) VALUES
('Gabriela Gómez Ruiz',         'CC', '1098111111', '3101111111'),
('Sofía López García',          'CC', '1098222222', '3202222222'),
('Julián Martínez Pérez',       'CC', '1045333333', '3003333333'),
('Carolina Vargas Silva',       'CC', '52444444',   '3124444444'),
('Tomás Jiménez Castro',        'CC', '1078555555', '3205555555'),
('Patricia Reyes Mora',         'CC', '41666666',   '3006666666'),
('Santiago Peña Lozano',        'CC', '1056777777', '3107777777'),
('Natalia Castro Ríos',         'CC', '1023888888', '3208888888'),
('Felipe Suárez Herrera',       'CC', '79999999',   '3009999999'),
('Daniela Rojas Cruz',          'CC', '1089000001', '3160000001');

-- Relación reserva-acompañante
INSERT INTO reserva_acompanante (id_reserva, id_acompanante) VALUES
(1,  1),  -- Carlos viajó con Gabriela
(2,  2),  -- María con Sofía
(3,  3),  -- Jorge con Julián
(3,  4),  -- Jorge también con Carolina (Suite)
(5,  5),  -- Pedro con Tomás
(7,  6),  -- Roberto con Patricia
(7,  7),  -- Roberto también con Santiago (Suite)
(11, 8),  -- Diego con Natalia (Presidencial)
(11, 9),  -- Diego con Felipe
(16, 10); -- Carlos (2a visita) con Daniela

-- Consumos de servicios (30)
INSERT INTO consumo_servicio (id_reserva, id_servicio, cantidad, precio_unit, fecha, notas) VALUES
(1,  1, 2, 45000, '2024-01-06 13:00:00', 'Almuerzo para 2'),
(1,  3, 1, 25000, '2024-01-07 20:00:00', 'Minibar'),
(2,  1, 3, 45000, '2024-01-11 19:30:00', 'Cena'),
(2,  4, 3, 20000, '2024-01-10 08:00:00', 'Parqueadero'),
(3,  1, 4, 45000, '2024-01-16 12:00:00', 'Almuerzo grupal'),
(3,  5, 1, 80000, '2024-01-15 10:00:00', 'Traslado aeropuerto'),
(3,  3, 2, 25000, '2024-01-17 22:00:00', 'Minibar noche'),
(4,  3, 1, 25000, '2024-02-02 21:00:00', 'Minibar'),
(5,  1, 2, 45000, '2024-02-11 20:00:00', 'Cena romántica'),
(5,  2, 2, 15000, '2024-02-13 09:00:00', 'Lavandería'),
(6,  1, 1, 45000, '2024-02-21 13:00:00', 'Almuerzo'),
(6,  4, 2, 20000, '2024-02-20 07:00:00', 'Parqueadero'),
(7,  1, 6, 45000, '2024-03-02 12:00:00', 'Almuerzo grupal Suite'),
(7,  5, 2, 80000, '2024-03-01 09:00:00', 'Tours locales'),
(7,  3, 3, 25000, '2024-03-04 23:00:00', 'Minibar'),
(8,  3, 1, 25000, '2024-03-11 20:00:00', 'Minibar'),
(9,  1, 2, 45000, '2024-03-16 13:00:00', 'Almuerzo'),
(10, 1, 3, 45000, '2024-04-02 19:00:00', 'Cena'),
(10, 4, 3, 20000, '2024-04-01 07:00:00', 'Parqueadero'),
(11, 1, 8, 45000, '2024-04-11 12:30:00', 'Almuerzo equipo'),
(11, 5, 3, 80000, '2024-04-12 09:00:00', 'Traslados'),
(11, 2, 5, 15000, '2024-04-14 10:00:00', 'Lavandería corporativa'),
(11, 3, 4, 25000, '2024-04-13 22:00:00', 'Minibar'),
(12, 4, 2, 20000, '2024-05-01 08:00:00', 'Parqueadero'),
(12, 1, 2, 45000, '2024-05-02 13:00:00', 'Almuerzo'),
(14, 1, 2, 45000, '2024-05-21 19:30:00', 'Cena'),
(14, 3, 2, 25000, '2024-05-22 21:00:00', 'Minibar'),
(15, 1, 3, 45000, '2024-06-02 12:00:00', 'Almuerzo'),
(15, 5, 1, 80000, '2024-06-03 10:00:00', 'Tour ciudad'),
(18, 1, 2, 45000, '2024-08-02 13:00:00', 'Almuerzo activo');

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================
