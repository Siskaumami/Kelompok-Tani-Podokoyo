DO $$
DECLARE old_constraint text;
BEGIN
  SELECT conname INTO old_constraint
  FROM pg_constraint
  WHERE conrelid='stock_opnames'::regclass
    AND contype='c'
    AND pg_get_constraintdef(oid) ILIKE '%COMPLETED%'
    AND pg_get_constraintdef(oid) ILIKE '%reason IS NOT NULL%'
  LIMIT 1;

  IF old_constraint IS NULL THEN
    RAISE EXCEPTION 'stock_opnames completed constraint not found';
  END IF;

  EXECUTE format(
    'ALTER TABLE stock_opnames DROP CONSTRAINT %I',
    old_constraint
  );
END $$;

ALTER TABLE stock_opnames
ADD CONSTRAINT stock_opnames_completed_consistency
CHECK (
  status <> 'COMPLETED'
  OR (
    physical_quantity IS NOT NULL
    AND difference = physical_quantity - baseline_quantity
    AND completed_at IS NOT NULL
    AND completed_by IS NOT NULL
    AND (difference = 0 OR reason IS NOT NULL)
  )
);