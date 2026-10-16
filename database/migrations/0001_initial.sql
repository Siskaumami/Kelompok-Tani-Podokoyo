CREATE TABLE organizations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, slug text NOT NULL UNIQUE,
 timezone text NOT NULL DEFAULT 'Asia/Jakarta', reminder_time time NOT NULL DEFAULT '19:00', reminders_enabled boolean NOT NULL DEFAULT true,
 reminder_email boolean NOT NULL DEFAULT false, grade_a_price_rp bigint NOT NULL DEFAULT 0 CHECK(grade_a_price_rp>=0),
 grade_a_hpp_rp bigint NOT NULL DEFAULT 0 CHECK(grade_a_hpp_rp>=0),
 village_title text NOT NULL DEFAULT '', village_body text NOT NULL DEFAULT '', village_image_id uuid,
 publication text NOT NULL DEFAULT 'DRAFT' CHECK(publication IN ('DRAFT','PUBLISHED')),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE users (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid REFERENCES organizations(id), email text NOT NULL UNIQUE CHECK(email=lower(email)),
 name text NOT NULL, password_hash text NOT NULL, role text NOT NULL CHECK(role IN ('SUPER_ADMIN','OWNER','ADMIN')),
 active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(org_id,id), CHECK((role='SUPER_ADMIN' AND org_id IS NULL) OR (role<>'SUPER_ADMIN' AND org_id IS NOT NULL))
);
CREATE TABLE sessions (
 token_hash text PRIMARY KEY, user_id uuid NOT NULL REFERENCES users(id), csrf_hash text NOT NULL,
 expires_at timestamptz NOT NULL, last_seen_at timestamptz NOT NULL DEFAULT now(), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sessions_user ON sessions(user_id);
CREATE TABLE auth_tokens (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid REFERENCES organizations(id), email text NOT NULL,
 token_hash text NOT NULL UNIQUE, kind text NOT NULL CHECK(kind IN ('RESET','INVITE')), name text NOT NULL DEFAULT '',
 expires_at timestamptz NOT NULL, consumed_at timestamptz, created_by uuid REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX auth_tokens_email ON auth_tokens(email,kind);
CREATE TABLE login_limits (key text PRIMARY KEY, attempts integer NOT NULL, window_start timestamptz NOT NULL);
CREATE TABLE file_objects (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL REFERENCES organizations(id), object_key text NOT NULL UNIQUE,
 mime text NOT NULL CHECK(mime='image/webp'), size_bytes integer NOT NULL CHECK(size_bytes>0 AND size_bytes<=5242880),
 uploaded_by uuid NOT NULL REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(org_id,id)
);
ALTER TABLE organizations ADD CONSTRAINT org_image FOREIGN KEY(id,village_image_id) REFERENCES file_objects(org_id,id);
CREATE TABLE farmers (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL REFERENCES organizations(id), name text NOT NULL,
 bio text NOT NULL DEFAULT '', image_id uuid, publication text NOT NULL DEFAULT 'DRAFT' CHECK(publication IN ('DRAFT','PUBLISHED')),
 archived boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(org_id,id),
 FOREIGN KEY(org_id,image_id) REFERENCES file_objects(org_id,id)
);
CREATE TABLE products (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL REFERENCES organizations(id), name text NOT NULL, sku text NOT NULL,
 description text NOT NULL DEFAULT '', image_id uuid, publication text NOT NULL DEFAULT 'DRAFT' CHECK(publication IN ('DRAFT','PUBLISHED')),
 shopee_url text NOT NULL DEFAULT '', tokopedia_url text NOT NULL DEFAULT '', whatsapp_url text NOT NULL DEFAULT '',
 archived boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(org_id,id), UNIQUE(org_id,sku),
 FOREIGN KEY(org_id,image_id) REFERENCES file_objects(org_id,id)
);
CREATE TABLE product_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, product_id uuid NOT NULL,
 version integer NOT NULL CHECK(version>0), material_g bigint NOT NULL CHECK(material_g>0),
 material_rp bigint NOT NULL CHECK(material_rp>=0), packaging_rp bigint NOT NULL CHECK(packaging_rp>=0),
 production_rp bigint NOT NULL CHECK(production_rp>=0), other_rp bigint NOT NULL CHECK(other_rp>=0),
 hpp_rp bigint GENERATED ALWAYS AS (material_rp+packaging_rp+production_rp+other_rp) STORED,
 price_rp bigint NOT NULL CHECK(price_rp>=0), changed_by uuid NOT NULL REFERENCES users(id),
 reason text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(org_id,id), UNIQUE(org_id,product_id,id), UNIQUE(org_id,product_id,version),
 FOREIGN KEY(org_id,product_id) REFERENCES products(org_id,id)
);
CREATE VIEW product_economics_history AS SELECT *,lead(created_at) OVER(PARTITION BY product_id ORDER BY version) AS effective_until FROM product_versions;
CREATE TABLE inventory_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL REFERENCES organizations(id), product_id uuid,
 kind text NOT NULL CHECK(kind IN ('GRADE_A','GRADE_B','FINISHED')), balance bigint NOT NULL DEFAULT 0 CHECK(balance>=0),
 revision bigint NOT NULL DEFAULT 0 CHECK(revision>=0), UNIQUE(org_id,id), UNIQUE(org_id,product_id),
 CHECK((kind='FINISHED' AND product_id IS NOT NULL) OR (kind<>'FINISHED' AND product_id IS NULL)),
 FOREIGN KEY(org_id,product_id) REFERENCES products(org_id,id)
);
CREATE UNIQUE INDEX inventory_raw_unique ON inventory_items(org_id,kind) WHERE product_id IS NULL;
CREATE TABLE harvests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL REFERENCES organizations(id), farmer_id uuid,
 business_date date NOT NULL, total_g bigint NOT NULL CHECK(total_g>0), grade_a_g bigint NOT NULL CHECK(grade_a_g>=0),
 grade_b_g bigint NOT NULL CHECK(grade_b_g>=0), reject_g bigint NOT NULL CHECK(reject_g>=0), notes text NOT NULL DEFAULT '',
 status text NOT NULL DEFAULT 'DRAFT' CHECK(status IN ('DRAFT','FINALIZED','VOIDED')), created_by uuid NOT NULL REFERENCES users(id),
 finalized_at timestamptz, void_reason text, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(org_id,id),
 FOREIGN KEY(org_id,farmer_id) REFERENCES farmers(org_id,id),
 CHECK(grade_a_g+grade_b_g+reject_g<=total_g), CHECK(status='DRAFT' OR grade_a_g+grade_b_g+reject_g=total_g),
 CHECK((status='DRAFT' AND finalized_at IS NULL) OR (status<>'DRAFT' AND finalized_at IS NOT NULL)), CHECK(status<>'VOIDED' OR length(void_reason)>0)
);
CREATE TABLE production_plans (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, product_id uuid NOT NULL,
 planned_g bigint NOT NULL CHECK(planned_g>0), business_date date NOT NULL,
 status text NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN','COMPLETED','CANCELLED','NEEDS_REVIEW')),
 notes text NOT NULL DEFAULT '', created_by uuid NOT NULL REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(org_id,id), UNIQUE(org_id,id,product_id),
 FOREIGN KEY(org_id,product_id) REFERENCES products(org_id,id)
);
CREATE TABLE production_batches (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, product_id uuid NOT NULL, version_id uuid NOT NULL, plan_id uuid,
 business_date date NOT NULL, actual_g bigint NOT NULL CHECK(actual_g>0), output_units bigint NOT NULL CHECK(output_units>0),
 theoretical_g bigint NOT NULL CHECK(theoretical_g>0), hpp_rp bigint NOT NULL CHECK(hpp_rp>=0),
 product_name_snapshot text NOT NULL, notes text NOT NULL DEFAULT '', status text NOT NULL DEFAULT 'COMPLETED' CHECK(status IN ('COMPLETED','VOIDED')),
 void_reason text, created_by uuid NOT NULL REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(org_id,id),
 FOREIGN KEY(org_id,product_id,version_id) REFERENCES product_versions(org_id,product_id,id),
 FOREIGN KEY(org_id,plan_id,product_id) REFERENCES production_plans(org_id,id,product_id), CHECK(status<>'VOIDED' OR length(void_reason)>0)
);
CREATE UNIQUE INDEX production_plan_once ON production_batches(org_id,plan_id) WHERE plan_id IS NOT NULL;
CREATE TABLE sales (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL REFERENCES organizations(id), business_date date NOT NULL,
 channel text NOT NULL CHECK(channel IN ('OFFLINE','WHATSAPP','SHOPEE','TOKOPEDIA')), external_ref text NOT NULL DEFAULT '',
 discount_rp bigint NOT NULL CHECK(discount_rp>=0), fee_rp bigint NOT NULL CHECK(fee_rp>=0), gross_rp bigint NOT NULL CHECK(gross_rp>=0),
 hpp_rp bigint NOT NULL CHECK(hpp_rp>=0), net_rp bigint GENERATED ALWAYS AS (gross_rp-discount_rp-fee_rp) STORED,
 status text NOT NULL DEFAULT 'COMPLETED' CHECK(status IN ('COMPLETED','VOIDED')), notes text NOT NULL DEFAULT '', void_reason text,
 created_by uuid NOT NULL REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(org_id,id),
 CHECK(discount_rp+fee_rp<=gross_rp), CHECK(status<>'VOIDED' OR length(void_reason)>0)
);
CREATE TABLE sale_lines (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, sale_id uuid NOT NULL, item_id uuid NOT NULL,
 product_id uuid, version_id uuid, kind text NOT NULL CHECK(kind IN ('GRADE_A','FINISHED')), name_snapshot text NOT NULL,
 quantity bigint NOT NULL CHECK(quantity>0), unit_price_rp bigint NOT NULL CHECK(unit_price_rp>=0), unit_hpp_rp bigint NOT NULL CHECK(unit_hpp_rp>=0),
 gross_rp bigint NOT NULL CHECK(gross_rp>=0), hpp_rp bigint NOT NULL CHECK(hpp_rp>=0),
 FOREIGN KEY(org_id,sale_id) REFERENCES sales(org_id,id), FOREIGN KEY(org_id,item_id) REFERENCES inventory_items(org_id,id),
 FOREIGN KEY(org_id,product_id,version_id) REFERENCES product_versions(org_id,product_id,id),
 CHECK((kind='GRADE_A' AND product_id IS NULL AND version_id IS NULL) OR (kind='FINISHED' AND product_id IS NOT NULL AND version_id IS NOT NULL))
);
CREATE INDEX sales_period ON sales(org_id,business_date,status);
CREATE INDEX sale_lines_sale ON sale_lines(org_id,sale_id);
CREATE TABLE stock_opnames (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, item_id uuid NOT NULL,
 baseline_quantity bigint NOT NULL CHECK(baseline_quantity>=0), baseline_revision bigint NOT NULL CHECK(baseline_revision>=0),
 physical_quantity bigint CHECK(physical_quantity>=0), difference bigint, reason text CHECK(reason IN ('SHRINKAGE_OR_DAMAGE','FAILED_PRODUCTION','PREVIOUS_INPUT_ERROR','UNRECORDED_SALE','UNRECORDED_PRODUCTION','MISSING_GOODS','OTHER')),
 notes text NOT NULL DEFAULT '', status text NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN','COMPLETED','CANCELLED')),
 created_by uuid NOT NULL REFERENCES users(id), completed_by uuid REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz,
 UNIQUE(org_id,id), FOREIGN KEY(org_id,item_id) REFERENCES inventory_items(org_id,id),
 CHECK(status<>'COMPLETED' OR (physical_quantity IS NOT NULL AND difference=physical_quantity-baseline_quantity AND reason IS NOT NULL AND completed_at IS NOT NULL AND completed_by IS NOT NULL)),
 CHECK(reason<>'OTHER' OR length(trim(notes))>0)
);
CREATE UNIQUE INDEX one_open_count ON stock_opnames(org_id,item_id) WHERE status='OPEN';
CREATE TABLE inventory_movements (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, item_id uuid NOT NULL, delta bigint NOT NULL,
 movement_type text NOT NULL CHECK(movement_type IN ('HARVEST_GRADE_A','HARVEST_GRADE_B','GRADE_A_SALE','PRODUCTION_CONSUMPTION','PRODUCTION_OUTPUT','FINISHED_GOOD_SALE','OPNAME_ADJUSTMENT','CORRECTION')),
 source_type text NOT NULL CHECK(source_type IN ('HARVEST','PRODUCTION','SALE','OPNAME')), source_id uuid NOT NULL,
 actor_id uuid NOT NULL REFERENCES users(id), reason text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(org_id,item_id) REFERENCES inventory_items(org_id,id)
);
CREATE INDEX movements_item ON inventory_movements(org_id,item_id,created_at);
CREATE INDEX movements_source ON inventory_movements(org_id,source_type,source_id);
CREATE FUNCTION immutable_history() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'immutable_history' USING ERRCODE='23514'; END $$;
CREATE TRIGGER movements_immutable BEFORE UPDATE OR DELETE ON inventory_movements FOR EACH ROW EXECUTE FUNCTION immutable_history();
CREATE TRIGGER versions_immutable BEFORE UPDATE OR DELETE ON product_versions FOR EACH ROW EXECUTE FUNCTION immutable_history();
CREATE TRIGGER lines_immutable BEFORE UPDATE OR DELETE ON sale_lines FOR EACH ROW EXECUTE FUNCTION immutable_history();
CREATE FUNCTION apply_movement() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 PERFORM id FROM organizations WHERE id=NEW.org_id FOR UPDATE;
 UPDATE inventory_items SET balance=balance+NEW.delta, revision=revision+1 WHERE org_id=NEW.org_id AND id=NEW.item_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'invalid_item' USING ERRCODE='23503'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER movement_balance AFTER INSERT ON inventory_movements FOR EACH ROW EXECUTE FUNCTION apply_movement();
CREATE FUNCTION protect_balance() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF (NEW.balance<>OLD.balance OR NEW.revision<>OLD.revision) AND pg_trigger_depth()<2 THEN RAISE EXCEPTION 'ledger_required' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER balance_guard BEFORE UPDATE ON inventory_items FOR EACH ROW EXECUTE FUNCTION protect_balance();
CREATE TABLE audit_logs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL REFERENCES organizations(id), actor_id uuid REFERENCES users(id), action text NOT NULL,
 entity_type text NOT NULL, entity_id uuid, before_data jsonb, after_data jsonb, reason text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_org_time ON audit_logs(org_id,created_at DESC);
CREATE TRIGGER audit_immutable BEFORE UPDATE OR DELETE ON audit_logs FOR EACH ROW EXECUTE FUNCTION immutable_history();
CREATE TABLE idempotency_keys (
 org_id uuid NOT NULL REFERENCES organizations(id), actor_id uuid NOT NULL REFERENCES users(id), key uuid NOT NULL, operation text NOT NULL, request_hash text NOT NULL,
 response jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(org_id,actor_id,key)
);
CREATE TABLE sales_day_confirmations (
 org_id uuid NOT NULL REFERENCES organizations(id), business_date date NOT NULL, status text NOT NULL CHECK(status IN ('COMPLETED','NO_SALES')),
 actor_id uuid NOT NULL REFERENCES users(id), updated_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(org_id,business_date)
);
CREATE TABLE reminders (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL REFERENCES organizations(id), business_date date NOT NULL,
 dismissed boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(org_id,business_date), UNIQUE(org_id,id)
);
CREATE TABLE push_subscriptions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, user_id uuid NOT NULL, endpoint text NOT NULL UNIQUE,
 p256dh text NOT NULL, auth text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), FOREIGN KEY(org_id,user_id) REFERENCES users(org_id,id), UNIQUE(org_id,id)
);
CREATE TABLE notification_deliveries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL, reminder_id uuid NOT NULL, user_id uuid NOT NULL, channel text NOT NULL CHECK(channel IN ('PUSH','EMAIL')),
 status text NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','SENT','FAILED')), attempts integer NOT NULL DEFAULT 0,
 last_error text, sent_at timestamptz, updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(reminder_id,user_id,channel),
 FOREIGN KEY(org_id,reminder_id) REFERENCES reminders(org_id,id), FOREIGN KEY(org_id,user_id) REFERENCES users(org_id,id)
);
-- Protect event headers and source links, not just their immutable detail rows.
CREATE FUNCTION protect_event_header() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'history_delete_forbidden' USING ERRCODE='23514'; END IF;
 IF OLD.status IN ('FINALIZED','COMPLETED','VOIDED','CANCELLED') THEN
  IF NOT (OLD.status IN ('FINALIZED','COMPLETED') AND NEW.status='VOIDED' AND length(trim(NEW.void_reason))>0
    AND (to_jsonb(NEW)-'status'-'void_reason'-'net_rp')=(to_jsonb(OLD)-'status'-'void_reason'-'net_rp')) THEN
   RAISE EXCEPTION 'immutable_event' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER harvest_history BEFORE UPDATE OR DELETE ON harvests FOR EACH ROW EXECUTE FUNCTION protect_event_header();
CREATE TRIGGER production_history BEFORE UPDATE OR DELETE ON production_batches FOR EACH ROW EXECUTE FUNCTION protect_event_header();
CREATE TRIGGER sale_history BEFORE UPDATE OR DELETE ON sales FOR EACH ROW EXECUTE FUNCTION protect_event_header();
CREATE FUNCTION validate_movement_source() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE valid_source boolean;
BEGIN
 IF NEW.source_type='HARVEST' THEN SELECT EXISTS(SELECT 1 FROM harvests WHERE org_id=NEW.org_id AND id=NEW.source_id) INTO valid_source;
 ELSIF NEW.source_type='PRODUCTION' THEN SELECT EXISTS(SELECT 1 FROM production_batches WHERE org_id=NEW.org_id AND id=NEW.source_id) INTO valid_source;
 ELSIF NEW.source_type='SALE' THEN SELECT EXISTS(SELECT 1 FROM sales WHERE org_id=NEW.org_id AND id=NEW.source_id) INTO valid_source;
 ELSIF NEW.source_type='OPNAME' THEN SELECT EXISTS(SELECT 1 FROM stock_opnames WHERE org_id=NEW.org_id AND id=NEW.source_id) INTO valid_source;
 END IF;
 IF NOT valid_source THEN RAISE EXCEPTION 'invalid_movement_source' USING ERRCODE='23503'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER movement_source BEFORE INSERT ON inventory_movements FOR EACH ROW EXECUTE FUNCTION validate_movement_source();
CREATE FUNCTION protect_item_structure() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='INSERT' AND (NEW.balance<>0 OR NEW.revision<>0) THEN RAISE EXCEPTION 'initial_balance_requires_ledger' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' AND (NEW.id<>OLD.id OR NEW.org_id<>OLD.org_id OR NEW.kind<>OLD.kind OR NEW.product_id IS DISTINCT FROM OLD.product_id) THEN RAISE EXCEPTION 'immutable_item' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER item_structure BEFORE INSERT OR UPDATE ON inventory_items FOR EACH ROW EXECUTE FUNCTION protect_item_structure();
CREATE TABLE password_reset_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), email text NOT NULL,
 status text NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','PROCESSING','SENT','SKIPPED','FAILED')),
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts>=0), last_error text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX pending_password_requests ON password_reset_requests(status,created_at) WHERE status<>'SENT' AND status<>'SKIPPED';
