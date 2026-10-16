DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM organizations o
    LEFT JOIN users u
      ON u.org_id = o.id
     AND u.role = 'OWNER'
    GROUP BY o.id
    HAVING count(u.id) <> 1
  ) THEN
    RAISE EXCEPTION 'owner_count_invalid';
  END IF;
END $$;

CREATE UNIQUE INDEX users_one_owner_per_org
ON users(org_id)
WHERE role = 'OWNER';