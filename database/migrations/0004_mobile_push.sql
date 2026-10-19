CREATE TABLE mobile_push_devices (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 org_id uuid NOT NULL,
 user_id uuid NOT NULL,
 fid text NOT NULL UNIQUE,
 platform text NOT NULL CHECK(platform IN ('ANDROID','IOS')),
 last_seen_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(org_id,id),
 FOREIGN KEY(org_id,user_id) REFERENCES users(org_id,id),
 CHECK(length(fid) BETWEEN 10 AND 255),
 CHECK(fid ~ '^[A-Za-z0-9_-]+$')
);

CREATE INDEX mobile_push_devices_user
 ON mobile_push_devices(org_id,user_id);