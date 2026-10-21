-- 0006_grade_b_raw_sales.sql
-- Allow raw Grade B sales from existing Grade B inventory, without creating a second balance.
-- The migration runner executes this file inside one transaction.
DO $$
DECLARE sale_kind text;
DECLARE sale_link text;
DECLARE movement_kind text;
BEGIN
 SELECT conname INTO STRICT sale_kind FROM pg_constraint
 WHERE conrelid='sale_lines'::regclass AND contype='c'
   AND pg_get_constraintdef(oid) LIKE '%GRADE_A%'
   AND pg_get_constraintdef(oid) LIKE '%FINISHED%'
   AND pg_get_constraintdef(oid) NOT LIKE '%product_id%';
 SELECT conname INTO STRICT sale_link FROM pg_constraint
 WHERE conrelid='sale_lines'::regclass AND contype='c'
   AND pg_get_constraintdef(oid) LIKE '%product_id IS NULL%'
   AND pg_get_constraintdef(oid) LIKE '%version_id IS NULL%';
 SELECT conname INTO STRICT movement_kind FROM pg_constraint
 WHERE conrelid='inventory_movements'::regclass AND contype='c'
   AND pg_get_constraintdef(oid) LIKE '%GRADE_A_SALE%'
   AND pg_get_constraintdef(oid) LIKE '%FINISHED_GOOD_SALE%';
 EXECUTE format('ALTER TABLE sale_lines DROP CONSTRAINT %I',sale_kind);
 EXECUTE format('ALTER TABLE sale_lines DROP CONSTRAINT %I',sale_link);
 EXECUTE format('ALTER TABLE inventory_movements DROP CONSTRAINT %I',movement_kind);
END $$;

ALTER TABLE sale_lines ADD CONSTRAINT sale_lines_kind_raw_b_check
 CHECK(kind IN ('GRADE_A','GRADE_B','FINISHED'));
ALTER TABLE sale_lines ADD CONSTRAINT sale_lines_product_link_raw_b_check
 CHECK((kind IN ('GRADE_A','GRADE_B') AND product_id IS NULL AND version_id IS NULL)
   OR (kind='FINISHED' AND product_id IS NOT NULL AND version_id IS NOT NULL));
ALTER TABLE inventory_movements ADD CONSTRAINT inventory_movements_type_raw_b_check
 CHECK(movement_type IN ('HARVEST_GRADE_A','HARVEST_GRADE_B','GRADE_A_SALE','GRADE_B_SALE',
 'PRODUCTION_CONSUMPTION','PRODUCTION_OUTPUT','FINISHED_GOOD_SALE','OPNAME_ADJUSTMENT','CORRECTION'));
