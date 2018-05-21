--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: rsnadb; Type: DATABASE; Schema: -; Owner: edge
--

CREATE DATABASE rsnadb WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


ALTER DATABASE rsnadb OWNER TO edge;

\connect rsnadb

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: rsnadb; Type: COMMENT; Schema: -; Owner: edge
--

COMMENT ON DATABASE rsnadb IS 'RSNA Edge Device Database
Authors: Wendy Zhu (Univ of Chicago) and Steve G Langer (Mayo Clinic)

Copyright (c) 2010, Radiological Society of North America
  All rights reserved.
  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
  Neither the name of the RSNA nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
  CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
  USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
  USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
  OF SUCH DAMAGE.';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: removealldashesandleading0(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION removealldashesandleading0() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
	patients_row RECORD;
	mrn_old text;
	mrn_new text;
	mrn_firstchar text;
	n_updated integer := 0;
	n_deleted integer := 0;
	patient_id_old integer;
	patient_id_new integer;
	exams_row RECORD;
	exam_id_old integer;
	exam_id_new integer;
	accession_no text;
BEGIN
	RAISE NOTICE 'Replacing all dashes from mrn field in patients table of rsnadb';
	FOR patients_row in SELECT * from patients where mrn like '%-%' LOOP
	   	mrn_old := patients_row.mrn;

		mrn_new := replace(mrn_old, '-', '');
		mrn_firstchar := substring(mrn_old from 1 for 1);
	
		IF mrn_firstchar = '0' THEN
			mrn_new := substring(mrn_new from 2);
		END IF;


		IF mrn_new = mrn_old THEN
			CONTINUE;
		ELSE
			RAISE NOTICE 'Old mrn:% -> New mrn:%', mrn_old, mrn_new;
		END IF;

		-- Now mrn is one record from patients table
		RAISE NOTICE 'Processing % ...', mrn_old;

		IF NOT EXISTS (SELECT 1 from patients where mrn=mrn_new) THEN
			RAISE NOTICE '==>Updating old MRN % to new MRN: %', mrn_old, mrn_new;
			UPDATE patients set mrn=mrn_new where mrn=mrn_old;
			n_updated := n_updated + 1;
		ELSE
			RAISE NOTICE '==>Deleting the old MRN: %', mrn_old;

			-- Get the old patient_id:
			SELECT INTO patient_id_old patient_id FROM patients WHERE mrn=mrn_old;
			-- Get the new patient_id:
			SELECT INTO patient_id_new patient_id FROM patients WHERE mrn=mrn_new;
			-- Replace the patient_id in exams table to new patient_id:
			FOR exams_row in SELECT * from exams WHERE patient_id=patient_id_old LOOP
				exam_id_old := exams_row.exam_id;
		   		accession_no := exams_row.accession_number;
				SELECT INTO exam_id_new exam_id FROM exams WHERE patient_id=patient_id_new AND accession_number=accession_no;

				-- If the <accession_no, patient_id_new> key already exists, then we just delete the row <accession_no, patient_id_old>:
				IF EXISTS (SELECT 1 FROM exams WHERE accession_number=accession_no AND patient_id=patient_id_new) THEN
					-- Make sure reports table has no dependency on exam's this recpord:
					IF EXISTS (SELECT 1 FROM reports WHERE exam_id=exam_id_old) THEN
						-- <exam_id, status, status_time_stamp> is a key or reports table, so we need to decide if we should delete or update:
						IF EXISTS (SELECT * FROM reports r1, reports r2 WHERE r1.exam_id=exam_id_old AND r2.exam_id=exam_id_new AND r1.status=r2.status AND r1.status_timestamp=r2.status_timestamp) THEN
							DELETE FROM reports WHERE exam_id = exam_id_old;
						ELSE
							UPDATE reports SET exam_id=exam_id_new WHERE exam_id=exam_id_old;
						END IF;
					END IF;

					DELETE FROM exams WHERE accession_number=accession_no AND patient_id=patient_id_old;

				-- Else we change the patient_id_old to patient_id_new:
				ELSE
					UPDATE exams SET patient_id=patient_id_new WHERE accession_number=accession_no AND patient_id=patient_id_old;
				END IF;

			END LOOP;
			
			-- Delete the old record in patient table:
			DELETE FROM patients WHERE mrn=mrn_old;

			n_deleted := n_deleted + 1;
		END IF;
	END LOOP;
	RAISE NOTICE '';
	RAISE NOTICE 'Totally updated % records and deleted % records.', n_updated, n_deleted;
	return '';
END;
$$;


ALTER FUNCTION public.removealldashesandleading0() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: configurations; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE configurations (
    key character varying NOT NULL,
    value character varying NOT NULL,
    modified_date timestamp with time zone DEFAULT now()
);


ALTER TABLE public.configurations OWNER TO edge;

--
-- Name: TABLE configurations; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE configurations IS 'This table is used to store applications specific config data as key/value pairs and takes the place of java properties files (rather then having it all aly about in plain text files);

a) paths to key things (ie dicom studies)
b) site prefix for generating RSNA ID''s
c) site delay for applying to report finalize before available to send to CH
d) Clearing House connection data
e) etc';


--
-- Name: devices; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE devices (
    device_id integer NOT NULL,
    ae_title character varying(256) NOT NULL,
    host character varying(256) NOT NULL,
    port_number character varying(10) NOT NULL,
    modified_date timestamp with time zone DEFAULT now()
);


ALTER TABLE public.devices OWNER TO edge;

--
-- Name: TABLE devices; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE devices IS 'Used to store DICOM connection info for mage sources, and possibly others

a) the DICOM triplet (for remote DICOM study sources)
b) ?

';


--
-- Name: devices_device_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE devices_device_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.devices_device_id_seq OWNER TO edge;

--
-- Name: devices_device_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE devices_device_id_seq OWNED BY devices.device_id;


--
-- Name: email_configurations; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE email_configurations (
    key character varying NOT NULL,
    value character varying NOT NULL,
    modified_date timestamp with time zone DEFAULT now()
);


ALTER TABLE public.email_configurations OWNER TO edge;

--
-- Name: TABLE email_configurations; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE email_configurations IS 'This table is used to store email configuration as key/value pairs';


--
-- Name: email_jobs; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE email_jobs (
    email_job_id integer NOT NULL,
    recipient character varying NOT NULL,
    subject character varying,
    body text,
    sent boolean DEFAULT false NOT NULL,
    failed boolean DEFAULT false NOT NULL,
    comments character varying,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone DEFAULT now()
);


ALTER TABLE public.email_jobs OWNER TO edge;

--
-- Name: TABLE email_jobs; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE email_jobs IS 'This table is used to store queued emails. Jobs within the queue will be handled by a worker thread which is responsible for handling any send failures and retrying failed jobs';


--
-- Name: email_jobs_email_job_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE email_jobs_email_job_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.email_jobs_email_job_id_seq OWNER TO edge;

--
-- Name: email_jobs_email_job_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE email_jobs_email_job_id_seq OWNED BY email_jobs.email_job_id;


--
-- Name: exams; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE exams (
    exam_id integer NOT NULL,
    accession_number character varying(50) NOT NULL,
    patient_id integer NOT NULL,
    exam_description character varying(256),
    modified_date timestamp with time zone DEFAULT now()
);


ALTER TABLE public.exams OWNER TO edge;

--
-- Name: TABLE exams; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE exams IS 'A listing of all ordered DICOM exams the system knows about. The report status is not stored here';


--
-- Name: exams_exam_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE exams_exam_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.exams_exam_id_seq OWNER TO edge;

--
-- Name: exams_exam_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE exams_exam_id_seq OWNED BY exams.exam_id;


--
-- Name: hipaa_audit_accession_numbers; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE hipaa_audit_accession_numbers (
    id integer NOT NULL,
    view_id integer,
    accession_number character varying(100),
    modified_date timestamp with time zone DEFAULT now()
);


ALTER TABLE public.hipaa_audit_accession_numbers OWNER TO edge;

--
-- Name: TABLE hipaa_audit_accession_numbers; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE hipaa_audit_accession_numbers IS 'Part of the HIPAA tracking for edge device auditing. This table and  "audit_mrns" report up to table HIPAA_views
';


--
-- Name: hipaa_audit_accession_numbers_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE hipaa_audit_accession_numbers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.hipaa_audit_accession_numbers_id_seq OWNER TO edge;

--
-- Name: hipaa_audit_accession_numbers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE hipaa_audit_accession_numbers_id_seq OWNED BY hipaa_audit_accession_numbers.id;


--
-- Name: hipaa_audit_mrns; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE hipaa_audit_mrns (
    id integer NOT NULL,
    view_id integer,
    mrn character varying(100),
    modified_date timestamp with time zone DEFAULT now()
);


ALTER TABLE public.hipaa_audit_mrns OWNER TO edge;

--
-- Name: TABLE hipaa_audit_mrns; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE hipaa_audit_mrns IS 'Part of the HIPAA tracking for edge device auditing. This table and  "audit_acessions" report up to table HIPAA_views
';


--
-- Name: hipaa_audit_mrns_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE hipaa_audit_mrns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.hipaa_audit_mrns_id_seq OWNER TO edge;

--
-- Name: hipaa_audit_mrns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE hipaa_audit_mrns_id_seq OWNED BY hipaa_audit_mrns.id;


--
-- Name: hipaa_audit_views; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE hipaa_audit_views (
    id integer NOT NULL,
    requesting_ip character varying(15),
    requesting_username character varying(100),
    requesting_uri text,
    modified_date timestamp with time zone DEFAULT now()
);


ALTER TABLE public.hipaa_audit_views OWNER TO edge;

--
-- Name: TABLE hipaa_audit_views; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE hipaa_audit_views IS 'Part of the HIPAA tracking for edge device auditing. This is the top level table that tracks who asked for what from where. The HIPAA tables "audfit_accession" and "audit_mrns" report up to this table';


--
-- Name: hipaa_audit_views_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE hipaa_audit_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.hipaa_audit_views_id_seq OWNER TO edge;

--
-- Name: hipaa_audit_views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE hipaa_audit_views_id_seq OWNED BY hipaa_audit_views.id;


--
-- Name: job_sets; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE job_sets (
    job_set_id integer NOT NULL,
    patient_id integer NOT NULL,
    user_id integer NOT NULL,
    email_address character varying(255),
    modified_date timestamp with time zone DEFAULT now(),
    delay_in_hrs integer DEFAULT 72,
    single_use_patient_id character varying(64) NOT NULL,
    send_on_complete boolean DEFAULT false NOT NULL,
    access_code character varying(64),
    send_to_site boolean DEFAULT false NOT NULL
);


ALTER TABLE public.job_sets OWNER TO edge;

--
-- Name: TABLE job_sets; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE job_sets IS 'This is one of a pair of tables that bind a patient to a edge device job, consisting of one or more exam accessions descrbing DICOM exams to send to the CH. The other table is JOBS
';


--
-- Name: COLUMN job_sets.email_address; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON COLUMN job_sets.email_address IS 'the email address the patient claimed at the time this job was submitted to the Clearing House';


--
-- Name: job_sets_job_set_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE job_sets_job_set_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.job_sets_job_set_id_seq OWNER TO edge;

--
-- Name: job_sets_job_set_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE job_sets_job_set_id_seq OWNED BY job_sets.job_set_id;


--
-- Name: jobs; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE jobs (
    job_id integer NOT NULL,
    job_set_id integer NOT NULL,
    exam_id integer NOT NULL,
    report_id integer,
    document_id character varying(100),
    modified_date timestamp with time zone DEFAULT now(),
    remaining_retries integer NOT NULL
);


ALTER TABLE public.jobs OWNER TO edge;

--
-- Name: TABLE jobs; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE jobs IS 'This is one of a pair of tables that bind a patient to a edge device job, consisting of one or more exam accessions descrbing DICOM exams to send to the CH. The other table is JOB_SETS
';


--
-- Name: jobs_job_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE jobs_job_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.jobs_job_id_seq OWNER TO edge;

--
-- Name: jobs_job_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE jobs_job_id_seq OWNED BY jobs.job_id;


--
-- Name: patient_merge_events; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE patient_merge_events (
    event_id integer NOT NULL,
    old_mrn character varying(50) NOT NULL,
    new_mrn character varying(50) NOT NULL,
    old_patient_id integer NOT NULL,
    new_patient_id integer NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    modified_date timestamp with time zone DEFAULT now()
);


ALTER TABLE public.patient_merge_events OWNER TO edge;

--
-- Name: TABLE patient_merge_events; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE patient_merge_events IS 'When it''s required to swap a patient to a new ID (say a john doe) this tracks the old and new MRN for rollback/auditing
';


--
-- Name: patient_merge_events_event_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE patient_merge_events_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.patient_merge_events_event_id_seq OWNER TO edge;

--
-- Name: patient_merge_events_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE patient_merge_events_event_id_seq OWNED BY patient_merge_events.event_id;


--
-- Name: patients; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE patients (
    patient_id integer NOT NULL,
    mrn character varying(50) NOT NULL,
    patient_name character varying,
    dob date,
    sex character(1),
    street character varying,
    city character varying(50),
    state character varying(30),
    zip_code character varying(30),
    modified_date timestamp with time zone DEFAULT now(),
    consent_timestamp timestamp with time zone,
    email_address character varying(255),
    rsna_id character varying(64)
);


ALTER TABLE public.patients OWNER TO edge;

--
-- Name: TABLE patients; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE patients IS 'a list of all patient demog sent via the HL7 MIRTH channel';


--
-- Name: COLUMN patients.patient_id; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON COLUMN patients.patient_id IS 'just the dbase created primary key';


--
-- Name: COLUMN patients.mrn; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON COLUMN patients.mrn IS 'the actual medical recrod number from the medical center';


--
-- Name: patients_patient_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE patients_patient_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.patients_patient_id_seq OWNER TO edge;

--
-- Name: patients_patient_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE patients_patient_id_seq OWNED BY patients.patient_id;


--
-- Name: reports; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE reports (
    report_id integer NOT NULL,
    exam_id integer NOT NULL,
    proc_code character varying,
    status character varying NOT NULL,
    status_timestamp timestamp with time zone NOT NULL,
    report_text text,
    signer character varying,
    dictator character varying,
    transcriber character varying,
    modified_date timestamp with time zone DEFAULT now()
);


ALTER TABLE public.reports OWNER TO edge;

--
-- Name: TABLE reports; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE reports IS 'This table contains exam report and exam status as sent from teh MIRTH HL7 channel. Combined with the Exams table, this provides all info needed to determine exam staus and location to create a job to send to the CH';


--
-- Name: reports_report_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE reports_report_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.reports_report_id_seq OWNER TO edge;

--
-- Name: reports_report_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE reports_report_id_seq OWNED BY reports.report_id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE roles (
    role_id integer NOT NULL,
    role_description character varying(50) NOT NULL,
    modified_date time with time zone DEFAULT now()
);


ALTER TABLE public.roles OWNER TO edge;

--
-- Name: TABLE roles; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE roles IS 'Combined with table Users, this table defines a user''s privelages
';


--
-- Name: schema_version; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE schema_version (
    id integer NOT NULL,
    version character varying,
    modified_date timestamp with time zone DEFAULT now()
);


ALTER TABLE public.schema_version OWNER TO edge;

--
-- Name: TABLE schema_version; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE schema_version IS 'Store database schema version';


--
-- Name: schema_version_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE schema_version_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.schema_version_id_seq OWNER TO edge;

--
-- Name: schema_version_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE schema_version_id_seq OWNED BY schema_version.id;


--
-- Name: status_codes; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE status_codes (
    status_code integer NOT NULL,
    description character varying(255),
    modified_date timestamp with time zone DEFAULT now()
);


ALTER TABLE public.status_codes OWNER TO edge;

--
-- Name: TABLE status_codes; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE status_codes IS 'Maps a job status number to a human readable format.

Values in the 20s are owned by the COntent-prep app

Values in the 30s are owned by the Content-send app';


--
-- Name: studies; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE studies (
    study_id integer NOT NULL,
    study_uid character varying(255) NOT NULL,
    exam_id integer NOT NULL,
    study_description character varying(255),
    study_date timestamp without time zone,
    modified_date timestamp with time zone DEFAULT now()
);


ALTER TABLE public.studies OWNER TO edge;

--
-- Name: TABLE studies; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE studies IS 'DICOM uid info for exams listed by accession in table Exams';


--
-- Name: studies_study_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE studies_study_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.studies_study_id_seq OWNER TO edge;

--
-- Name: studies_study_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE studies_study_id_seq OWNED BY studies.study_id;


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE transactions (
    transaction_id integer NOT NULL,
    job_id integer NOT NULL,
    status_code integer NOT NULL,
    comments character varying,
    modified_date timestamp with time zone DEFAULT now()
);


ALTER TABLE public.transactions OWNER TO edge;

--
-- Name: TABLE transactions; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE transactions IS 'status logging/auditing for jobs defined in table Jobs. The java apps come here to determine their work by looking at the value status';


--
-- Name: COLUMN transactions.status_code; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON COLUMN transactions.status_code IS 'WHen a job is created by the GUI Token app, the row is created with value 1

Prepare Content looks for value of one and promites status to 2 on exit

Content transfer looks for status 2 and promotes to 3 on exit

 ';


--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE transactions_transaction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transactions_transaction_id_seq OWNER TO edge;

--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE transactions_transaction_id_seq OWNED BY transactions.transaction_id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: edge; Tablespace: 
--

CREATE TABLE users (
    user_id integer NOT NULL,
    user_login character varying(40) DEFAULT NULL::character varying,
    user_name character varying(100) DEFAULT ''::character varying,
    email character varying(100) DEFAULT NULL::character varying,
    crypted_password character varying(40) DEFAULT NULL::character varying,
    salt character varying(40) DEFAULT NULL::character varying,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    remember_token character varying(40) DEFAULT NULL::character varying,
    remember_token_expires_at timestamp with time zone,
    role_id integer NOT NULL,
    modified_date timestamp with time zone DEFAULT now(),
    active boolean DEFAULT true
);


ALTER TABLE public.users OWNER TO edge;

--
-- Name: TABLE users; Type: COMMENT; Schema: public; Owner: edge
--

COMMENT ON TABLE users IS 'Combined with table Roles, this table defines who can do what on the Edge appliacne Web GUI';


--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: edge
--

CREATE SEQUENCE users_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_user_id_seq OWNER TO edge;

--
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: edge
--

ALTER SEQUENCE users_user_id_seq OWNED BY users.user_id;


--
-- Name: v_consented; Type: VIEW; Schema: public; Owner: edge
--

CREATE VIEW v_consented AS
    SELECT patients.patient_id, patients.mrn, patients.patient_name, patients.dob, patients.sex, patients.street, patients.city, patients.state, patients.zip_code, patients.modified_date, patients.consent_timestamp, patients.email_address, patients.rsna_id FROM patients WHERE (patients.consent_timestamp IS NOT NULL);


ALTER TABLE public.v_consented OWNER TO edge;

--
-- Name: v_exam_status; Type: VIEW; Schema: public; Owner: edge
--

CREATE VIEW v_exam_status AS
    SELECT p.patient_id, p.mrn, p.patient_name, p.dob, p.sex, p.street, p.city, p.state, p.zip_code, p.email_address, e.exam_id, e.accession_number, e.exam_description, r.report_id, r.status, r.status_timestamp, r.report_text, r.dictator, r.transcriber, r.signer FROM ((patients p JOIN exams e ON ((p.patient_id = e.patient_id))) JOIN (SELECT r1.report_id, r1.exam_id, r1.proc_code, r1.status, r1.status_timestamp, r1.report_text, r1.signer, r1.dictator, r1.transcriber, r1.modified_date FROM reports r1 WHERE (r1.report_id = (SELECT r2.report_id FROM reports r2 WHERE (r2.exam_id = r1.exam_id) ORDER BY r2.report_id DESC LIMIT 1))) r ON ((e.exam_id = r.exam_id)));


ALTER TABLE public.v_exam_status OWNER TO edge;

--
-- Name: v_exams_sent; Type: VIEW; Schema: public; Owner: edge
--

CREATE VIEW v_exams_sent AS
    SELECT transactions.transaction_id, transactions.job_id, transactions.status_code, transactions.comments, transactions.modified_date FROM transactions WHERE (transactions.status_code = 40);


ALTER TABLE public.v_exams_sent OWNER TO edge;

--
-- Name: v_job_status; Type: VIEW; Schema: public; Owner: edge
--

CREATE VIEW v_job_status AS
    SELECT js.job_set_id, j.job_id, j.exam_id, js.delay_in_hrs, t.status, t.status_message, t.modified_date AS last_transaction_timestamp, js.single_use_patient_id, js.email_address, t.comments, js.send_on_complete, j.remaining_retries, js.send_to_site FROM ((jobs j JOIN job_sets js ON ((j.job_set_id = js.job_set_id))) JOIN (SELECT t1.job_id, t1.status_code AS status, sc.description AS status_message, t1.comments, t1.modified_date FROM (transactions t1 JOIN status_codes sc ON ((t1.status_code = sc.status_code))) WHERE (t1.modified_date = (SELECT max(t2.modified_date) AS max FROM transactions t2 WHERE (t2.job_id = t1.job_id)))) t ON ((j.job_id = t.job_id)));


ALTER TABLE public.v_job_status OWNER TO edge;

--
-- Name: v_langer_exam_status; Type: VIEW; Schema: public; Owner: edge
--

CREATE VIEW v_langer_exam_status AS
    SELECT patients.mrn, patients.patient_id, exams.accession_number, exams.exam_description, exams.modified_date, reports.status FROM patients, exams, reports WHERE (((patients.patient_id = exams.patient_id) AND (exams.exam_id = reports.exam_id)) AND (((reports.status)::text ~~ 'FINALIZED'::text) OR ((reports.status)::text ~~ 'ORDERED'::text))) ORDER BY patients.mrn;


ALTER TABLE public.v_langer_exam_status OWNER TO edge;

--
-- Name: v_patients_sent; Type: VIEW; Schema: public; Owner: edge
--

CREATE VIEW v_patients_sent AS
    SELECT DISTINCT job_sets.patient_id FROM transactions, jobs, job_sets WHERE (((transactions.status_code = 40) AND (transactions.job_id = jobs.job_id)) AND (jobs.job_set_id = job_sets.job_set_id));


ALTER TABLE public.v_patients_sent OWNER TO edge;

--
-- Name: device_id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY devices ALTER COLUMN device_id SET DEFAULT nextval('devices_device_id_seq'::regclass);


--
-- Name: email_job_id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY email_jobs ALTER COLUMN email_job_id SET DEFAULT nextval('email_jobs_email_job_id_seq'::regclass);


--
-- Name: exam_id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY exams ALTER COLUMN exam_id SET DEFAULT nextval('exams_exam_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY hipaa_audit_accession_numbers ALTER COLUMN id SET DEFAULT nextval('hipaa_audit_accession_numbers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY hipaa_audit_mrns ALTER COLUMN id SET DEFAULT nextval('hipaa_audit_mrns_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY hipaa_audit_views ALTER COLUMN id SET DEFAULT nextval('hipaa_audit_views_id_seq'::regclass);


--
-- Name: job_set_id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY job_sets ALTER COLUMN job_set_id SET DEFAULT nextval('job_sets_job_set_id_seq'::regclass);


--
-- Name: job_id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY jobs ALTER COLUMN job_id SET DEFAULT nextval('jobs_job_id_seq'::regclass);


--
-- Name: event_id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY patient_merge_events ALTER COLUMN event_id SET DEFAULT nextval('patient_merge_events_event_id_seq'::regclass);


--
-- Name: patient_id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY patients ALTER COLUMN patient_id SET DEFAULT nextval('patients_patient_id_seq'::regclass);


--
-- Name: report_id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY reports ALTER COLUMN report_id SET DEFAULT nextval('reports_report_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY schema_version ALTER COLUMN id SET DEFAULT nextval('schema_version_id_seq'::regclass);


--
-- Name: study_id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY studies ALTER COLUMN study_id SET DEFAULT nextval('studies_study_id_seq'::regclass);


--
-- Name: transaction_id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY transactions ALTER COLUMN transaction_id SET DEFAULT nextval('transactions_transaction_id_seq'::regclass);


--
-- Name: user_id; Type: DEFAULT; Schema: public; Owner: edge
--

ALTER TABLE ONLY users ALTER COLUMN user_id SET DEFAULT nextval('users_user_id_seq'::regclass);


--
-- Name: pk_device_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY devices
    ADD CONSTRAINT pk_device_id PRIMARY KEY (device_id);


--
-- Name: pk_email_job_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY email_jobs
    ADD CONSTRAINT pk_email_job_id PRIMARY KEY (email_job_id);


--
-- Name: pk_event_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY patient_merge_events
    ADD CONSTRAINT pk_event_id PRIMARY KEY (event_id);


--
-- Name: pk_exam_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY exams
    ADD CONSTRAINT pk_exam_id PRIMARY KEY (exam_id);


--
-- Name: pk_hipaa_audit_accession_number_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY hipaa_audit_accession_numbers
    ADD CONSTRAINT pk_hipaa_audit_accession_number_id PRIMARY KEY (id);


--
-- Name: pk_hipaa_audit_mrn_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY hipaa_audit_mrns
    ADD CONSTRAINT pk_hipaa_audit_mrn_id PRIMARY KEY (id);


--
-- Name: pk_hipaa_audit_view_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY hipaa_audit_views
    ADD CONSTRAINT pk_hipaa_audit_view_id PRIMARY KEY (id);


--
-- Name: pk_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY schema_version
    ADD CONSTRAINT pk_id PRIMARY KEY (id);


--
-- Name: pk_job_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY jobs
    ADD CONSTRAINT pk_job_id PRIMARY KEY (job_id);


--
-- Name: pk_job_set_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY job_sets
    ADD CONSTRAINT pk_job_set_id PRIMARY KEY (job_set_id);


--
-- Name: pk_patient_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY patients
    ADD CONSTRAINT pk_patient_id PRIMARY KEY (patient_id);


--
-- Name: pk_report_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY reports
    ADD CONSTRAINT pk_report_id PRIMARY KEY (report_id);


--
-- Name: pk_role_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY roles
    ADD CONSTRAINT pk_role_id PRIMARY KEY (role_id);


--
-- Name: pk_status_code; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY status_codes
    ADD CONSTRAINT pk_status_code PRIMARY KEY (status_code);


--
-- Name: pk_study_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY studies
    ADD CONSTRAINT pk_study_id PRIMARY KEY (study_id);


--
-- Name: pk_transaction_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT pk_transaction_id PRIMARY KEY (transaction_id);


--
-- Name: pk_user_id; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT pk_user_id PRIMARY KEY (user_id);


--
-- Name: uq_login; Type: CONSTRAINT; Schema: public; Owner: edge; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT uq_login UNIQUE (user_login);


--
-- Name: exams_patient_id_accession_number_idx; Type: INDEX; Schema: public; Owner: edge; Tablespace: 
--

CREATE INDEX exams_patient_id_accession_number_idx ON exams USING btree (patient_id, accession_number);


--
-- Name: exams_patient_id_idx; Type: INDEX; Schema: public; Owner: edge; Tablespace: 
--

CREATE INDEX exams_patient_id_idx ON exams USING btree (patient_id);


--
-- Name: job_sets_patient_id_idx; Type: INDEX; Schema: public; Owner: edge; Tablespace: 
--

CREATE INDEX job_sets_patient_id_idx ON job_sets USING btree (patient_id);


--
-- Name: patients_mrn_ix; Type: INDEX; Schema: public; Owner: edge; Tablespace: 
--

CREATE UNIQUE INDEX patients_mrn_ix ON patients USING btree (mrn);


--
-- Name: patients_name_mrn_dob_idx; Type: INDEX; Schema: public; Owner: edge; Tablespace: 
--

CREATE UNIQUE INDEX patients_name_mrn_dob_idx ON patients USING btree (patient_name, mrn, dob);


--
-- Name: patients_patient_id_name_mrn_dob_idx; Type: INDEX; Schema: public; Owner: edge; Tablespace: 
--

CREATE UNIQUE INDEX patients_patient_id_name_mrn_dob_idx ON patients USING btree (patient_id, patient_name, mrn, dob);


--
-- Name: reports_exam_id_status_status_timestamp_idx; Type: INDEX; Schema: public; Owner: edge; Tablespace: 
--

CREATE INDEX reports_exam_id_status_status_timestamp_idx ON reports USING btree (exam_id, status, status_timestamp);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

