-- Corrige el error de tipeo en la categoría de reparación:
-- "Inmoviliario" -> "Inmobiliario". Solo cambia el nombre; el ID y los
-- tickets asociados quedan igual.
UPDATE "CategoriaReparacion" SET "nombre" = 'Inmobiliario' WHERE "nombre" = 'Inmoviliario';
