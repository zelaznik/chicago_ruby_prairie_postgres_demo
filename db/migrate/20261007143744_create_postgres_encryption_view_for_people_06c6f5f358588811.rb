class CreatePostgresEncryptionViewForPeople06c6f5f358588811 < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      ALTER TABLE people RENAME TO people_encrypted;

      CREATE VIEW "people" AS
      SELECT
        id,
        username,
        status,
        encrypted_ssn,
        encrypted_ssn_iv,
        created_at,
        updated_at,
        pgp_sym_decrypt( pg_encrypted_ssn::bytea, current_setting('app.encryption_key') ) AS ssn
      FROM
        "people_encrypted";

      ALTER VIEW "people" ALTER COLUMN status SET DEFAULT 'active'::text;

      CREATE FUNCTION people_create_06c6f5f358588811() RETURNS TRIGGER AS $$
        BEGIN
          INSERT INTO people_encrypted (
            id,
            username,
            status,
            encrypted_ssn,
            encrypted_ssn_iv,
            created_at,
            updated_at,
            pg_encrypted_ssn
          ) VALUES (
            COALESCE(NEW.id, nextval('people_id_seq'::regclass)),
            NEW.username,
            COALESCE(NEW.status, 'active'::text),
            NEW.encrypted_ssn,
            NEW.encrypted_ssn_iv,
            NEW.created_at,
            NEW.updated_at,
            pgp_sym_encrypt( NEW.ssn::text, current_setting('app.encryption_key') )
          )

          RETURNING id INTO NEW.id;

          RETURN NEW;
        END;
      $$ LANGUAGE 'plpgsql';

      CREATE TRIGGER trg_instead_of_insert_on_people_encrypted_06c6f5f358588811
      INSTEAD OF INSERT ON people
      FOR EACH ROW EXECUTE PROCEDURE people_create_06c6f5f358588811();

      CREATE FUNCTION people_update_06c6f5f358588811() RETURNS TRIGGER AS $$
        BEGIN
          UPDATE
            "people_encrypted"
          SET
            id = NEW.id,
            username = NEW.username,
            status = NEW.status,
            encrypted_ssn = NEW.encrypted_ssn,
            encrypted_ssn_iv = NEW.encrypted_ssn_iv,
            created_at = NEW.created_at,
            updated_at = NEW.updated_at
          WHERE
            id = NEW.id;

          IF (NEW.ssn IS DISTINCT FROM OLD.ssn) THEN
            UPDATE people_encrypted
            SET pg_encrypted_ssn = pgp_sym_encrypt(
              NEW.ssn::text,
              current_setting('app.encryption_key')
            )
            WHERE id = NEW.id;
          END IF;

          RETURN NEW;
        END;
      $$ LANGUAGE 'plpgsql';

      CREATE TRIGGER trg_instead_of_update_on_people_encrypted_06c6f5f358588811
      INSTEAD OF UPDATE ON people
      FOR EACH ROW EXECUTE PROCEDURE people_update_06c6f5f358588811();

      CREATE OR REPLACE RULE _before_delete_on_people_encrypted_06c6f5f358588811 AS
      ON DELETE TO people DO INSTEAD (
        DELETE FROM people_encrypted WHERE id = OLD.id;
      );
    SQL
  end

  def down
    execute <<~SQL
      DROP RULE _before_delete_on_people_encrypted_06c6f5f358588811 ON people;

      DROP TRIGGER trg_instead_of_update_on_people_encrypted_06c6f5f358588811 ON people;
      DROP FUNCTION people_update_06c6f5f358588811;

      DROP TRIGGER trg_instead_of_insert_on_people_encrypted_06c6f5f358588811 ON people;
      DROP FUNCTION people_create_06c6f5f358588811;

      DROP VIEW people;

      ALTER TABLE people_encrypted RENAME TO people;
    SQL
  end
end
