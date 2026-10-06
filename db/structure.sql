SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: people_create_370ed45a8097674b(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.people_create_370ed45a8097674b() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: people_update_370ed45a8097674b(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.people_update_370ed45a8097674b() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: people_encrypted; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.people_encrypted (
    id bigint NOT NULL,
    username text,
    status text DEFAULT 'active'::text NOT NULL,
    encrypted_ssn text,
    encrypted_ssn_iv text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    pg_encrypted_ssn text
);


--
-- Name: people; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.people AS
 SELECT id,
    username,
    status,
    encrypted_ssn,
    encrypted_ssn_iv,
    created_at,
    updated_at,
    public.pgp_sym_decrypt((pg_encrypted_ssn)::bytea, current_setting('app.encryption_key'::text)) AS ssn
   FROM public.people_encrypted;


--
-- Name: people_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.people_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: people_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.people_id_seq OWNED BY public.people_encrypted.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: people_encrypted id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people_encrypted ALTER COLUMN id SET DEFAULT nextval('public.people_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: people_encrypted people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people_encrypted
    ADD CONSTRAINT people_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: people _before_delete_on_people_encrypted_370ed45a8097674b; Type: RULE; Schema: public; Owner: -
--

CREATE RULE _before_delete_on_people_encrypted_370ed45a8097674b AS
    ON DELETE TO public.people DO INSTEAD  DELETE FROM public.people_encrypted
  WHERE (people_encrypted.id = old.id);


--
-- Name: people trg_instead_of_insert_on_people_encrypted_370ed45a8097674b; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_instead_of_insert_on_people_encrypted_370ed45a8097674b INSTEAD OF INSERT ON public.people FOR EACH ROW EXECUTE FUNCTION public.people_create_370ed45a8097674b();


--
-- Name: people trg_instead_of_update_on_people_encrypted_370ed45a8097674b; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_instead_of_update_on_people_encrypted_370ed45a8097674b INSTEAD OF UPDATE ON public.people FOR EACH ROW EXECUTE FUNCTION public.people_update_370ed45a8097674b();


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261006171045'),
('20261006135448'),
('20261006095744'),
('20261006010613'),
('20261005181011');

