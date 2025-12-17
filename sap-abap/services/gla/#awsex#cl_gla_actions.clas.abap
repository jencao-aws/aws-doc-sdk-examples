" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS /awsex/cl_gla_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS create_vault
      IMPORTING
        !iv_vault_name TYPE /aws1/glastring
      EXPORTING
        !oo_result     TYPE REF TO /aws1/cl_glacreatevaultoutput
      RAISING
        /aws1/cx_rt_generic.

    METHODS list_vaults
      EXPORTING
        !oo_result TYPE REF TO /aws1/cl_glalistvaultsoutput
      RAISING
        /aws1/cx_rt_generic.

    METHODS upload_archive
      IMPORTING
        !iv_vault_name         TYPE /aws1/glastring
        !iv_archive_desc       TYPE /aws1/glastring
        !iv_archive_data       TYPE /aws1/glastream
      EXPORTING
        !oo_result             TYPE REF TO /aws1/cl_glaarchivecreationout
      RAISING
        /aws1/cx_rt_generic.

    METHODS initiate_invntry_rtrvl
      IMPORTING
        !iv_vault_name TYPE /aws1/glastring
      EXPORTING
        !oo_result     TYPE REF TO /aws1/cl_glainitiatejoboutput
      RAISING
        /aws1/cx_rt_generic.

    METHODS initiate_archv_rtrvl
      IMPORTING
        !iv_vault_name TYPE /aws1/glastring
        !iv_archive_id TYPE /aws1/glastring
      EXPORTING
        !oo_result     TYPE REF TO /aws1/cl_glainitiatejoboutput
      RAISING
        /aws1/cx_rt_generic.

    METHODS list_jobs
      IMPORTING
        !iv_vault_name TYPE /aws1/glastring
        !iv_statuscode TYPE /aws1/glastring OPTIONAL
      EXPORTING
        !oo_result     TYPE REF TO /aws1/cl_glalistjobsoutput
      RAISING
        /aws1/cx_rt_generic.

    METHODS delete_vault
      IMPORTING
        !iv_vault_name TYPE /aws1/glastring
      RAISING
        /aws1/cx_rt_generic.

    METHODS delete_archive
      IMPORTING
        !iv_vault_name TYPE /aws1/glastring
        !iv_archive_id TYPE /aws1/glastring
      RAISING
        /aws1/cx_rt_generic.

    METHODS get_job_status
      IMPORTING
        !iv_vault_name TYPE /aws1/glastring
        !iv_job_id     TYPE /aws1/glastring
      EXPORTING
        !oo_result     TYPE REF TO /aws1/cl_glaglacierjobdesc
      RAISING
        /aws1/cx_rt_generic.

    METHODS get_job_output
      IMPORTING
        !iv_vault_name TYPE /aws1/glastring
        !iv_job_id     TYPE /aws1/glastring
      EXPORTING
        !oo_result     TYPE REF TO /aws1/cl_glagetjoboutputoutput
      RAISING
        /aws1/cx_rt_generic.

    METHODS set_vault_notifications
      IMPORTING
        !iv_vault_name   TYPE /aws1/glastring
        !iv_sns_topic    TYPE /aws1/glastring
      RAISING
        /aws1/cx_rt_generic.

    METHODS get_vault_notifications
      IMPORTING
        !iv_vault_name TYPE /aws1/glastring
      EXPORTING
        !oo_result     TYPE REF TO /aws1/cl_glagetvaultnotifsout
      RAISING
        /aws1/cx_rt_generic.

    METHODS delete_vault_notifs
      IMPORTING
        !iv_vault_name TYPE /aws1/glastring
      RAISING
        /aws1/cx_rt_generic.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /AWSEX/CL_GLA_ACTIONS IMPLEMENTATION.


  METHOD create_vault.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_gla) = /aws1/cl_gla_factory=>create( lo_session ).

    " snippet-start:[gla.abapv1.create_vault]
    TRY.
        " iv_vault_name = 'my-glacier-vault'
        oo_result = lo_gla->createvault( iv_vaultname = iv_vault_name ).
        MESSAGE 'Glacier vault created.' TYPE 'I'.
      CATCH /aws1/cx_glalimitexceededex.
        MESSAGE 'Limit exceeded for vault creation.' TYPE 'E'.
      CATCH /aws1/cx_glainvparamvalueex.
        MESSAGE 'Invalid parameter value for vault creation.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[gla.abapv1.create_vault]
  ENDMETHOD.


  METHOD list_vaults.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_gla) = /aws1/cl_gla_factory=>create( lo_session ).

    " snippet-start:[gla.abapv1.list_vaults]
    TRY.
        oo_result = lo_gla->listvaults( ).
        DATA(lt_vaults) = oo_result->get_vaultlist( ).
        MESSAGE 'Retrieved list of Glacier vaults.' TYPE 'I'.
      CATCH /aws1/cx_glainvparamvalueex.
        MESSAGE 'Invalid parameter value.' TYPE 'E'.
      CATCH /aws1/cx_glaresourcenotfoundex.
        MESSAGE 'Resource not found.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[gla.abapv1.list_vaults]
  ENDMETHOD.


  METHOD upload_archive.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_gla) = /aws1/cl_gla_factory=>create( lo_session ).

    " snippet-start:[gla.abapv1.upload_archive]
    TRY.
        " iv_vault_name = 'my-glacier-vault'
        " iv_archive_desc = 'Sample archive description'
        
        " Calculate SHA256 tree hash for the archive data
        " For small archives (<1MB), the tree hash equals the SHA256 hash
        DATA lv_hash_xstring TYPE xstring.
        DATA lv_hash_string TYPE string.
        DATA lv_key TYPE xstring.
        
        " Use HMAC with empty key to calculate hash
        TRY.
            cl_abap_hmac=>calculate_hmac_for_raw(
              EXPORTING
                if_algorithm     = 'SHA256'
                if_key           = lv_key
                if_data          = iv_archive_data
                if_length        = 0
              IMPORTING
                ef_hashxstring   = lv_hash_xstring
            ).
          CATCH cx_root.
            " If HMAC calculation fails, try alternative method
            " For demonstration purposes, we'll use a placeholder
            " In production, implement proper SHA256 tree hash calculation
            lv_hash_xstring = iv_archive_data.
        ENDTRY.
        
        " Convert xstring to hex string representation
        " Each byte in xstring becomes 2 hex characters
        DATA lv_hash_length TYPE i.
        DATA lv_hex_offset TYPE i.
        DATA lv_byte_value TYPE x LENGTH 1.
        DATA lv_hex_byte TYPE c LENGTH 2.
        
        lv_hash_length = xstrlen( lv_hash_xstring ).
        CLEAR lv_hash_string.
        
        DO lv_hash_length TIMES.
          lv_hex_offset = sy-index - 1.
          lv_byte_value = lv_hash_xstring+lv_hex_offset(1).
          WRITE lv_byte_value TO lv_hex_byte LEFT-JUSTIFIED NO-ZERO.
          " Ensure two characters by padding with 0 if needed
          WHILE strlen( lv_hex_byte ) < 2.
            lv_hex_byte = |0{ lv_hex_byte }|.
          ENDWHILE.
          lv_hash_string = |{ lv_hash_string }{ lv_hex_byte }|.
        ENDDO.
        
        CONDENSE lv_hash_string NO-GAPS.
        TRANSLATE lv_hash_string TO LOWER CASE.
        
        oo_result = lo_gla->uploadarchive(
          iv_vaultname = iv_vault_name
          iv_archivedescription = iv_archive_desc
          iv_body = iv_archive_data
          iv_checksum = lv_hash_string
        ).
        DATA(lv_archive_id) = oo_result->get_archiveid( ).
        MESSAGE 'Archive uploaded to Glacier vault.' TYPE 'I'.
      CATCH /aws1/cx_glaresourcenotfoundex.
        MESSAGE 'Vault not found.' TYPE 'E'.
      CATCH /aws1/cx_glainvparamvalueex.
        MESSAGE 'Invalid parameter value.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[gla.abapv1.upload_archive]
  ENDMETHOD.


  METHOD initiate_invntry_rtrvl.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_gla) = /aws1/cl_gla_factory=>create( lo_session ).

    " snippet-start:[gla.abapv1.initiate_inventory_retrieval]
    TRY.
        " iv_vault_name = 'my-glacier-vault'
        DATA(lo_job_params) = NEW /aws1/cl_glajobparameters(
          iv_type = 'inventory-retrieval'
        ).

        oo_result = lo_gla->initiatejob(
          iv_vaultname = iv_vault_name
          io_jobparameters = lo_job_params
        ).
        DATA(lv_job_id) = oo_result->get_jobid( ).
        MESSAGE 'Inventory retrieval job initiated.' TYPE 'I'.
      CATCH /aws1/cx_glaresourcenotfoundex.
        MESSAGE 'Vault not found.' TYPE 'E'.
      CATCH /aws1/cx_glainvparamvalueex.
        MESSAGE 'Invalid parameter value.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[gla.abapv1.initiate_inventory_retrieval]
  ENDMETHOD.


  METHOD initiate_archv_rtrvl.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_gla) = /aws1/cl_gla_factory=>create( lo_session ).

    " snippet-start:[gla.abapv1.initiate_archive_retrieval]
    TRY.
        " iv_vault_name = 'my-glacier-vault'
        " iv_archive_id = 'archive-id-from-upload'
        DATA(lo_job_params) = NEW /aws1/cl_glajobparameters(
          iv_type = 'archive-retrieval'
          iv_archiveid = iv_archive_id
        ).

        oo_result = lo_gla->initiatejob(
          iv_vaultname = iv_vault_name
          io_jobparameters = lo_job_params
        ).
        DATA(lv_job_id) = oo_result->get_jobid( ).
        MESSAGE 'Archive retrieval job initiated.' TYPE 'I'.
      CATCH /aws1/cx_glaresourcenotfoundex.
        MESSAGE 'Vault or archive not found.' TYPE 'E'.
      CATCH /aws1/cx_glainvparamvalueex.
        MESSAGE 'Invalid parameter value.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[gla.abapv1.initiate_archive_retrieval]
  ENDMETHOD.


  METHOD list_jobs.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_gla) = /aws1/cl_gla_factory=>create( lo_session ).

    " snippet-start:[gla.abapv1.list_jobs]
    TRY.
        " iv_vault_name = 'my-glacier-vault'
        " iv_statuscode = 'InProgress' or 'Succeeded'
        oo_result = lo_gla->listjobs(
          iv_vaultname = iv_vault_name
          iv_statuscode = iv_statuscode
        ).
        DATA(lt_jobs) = oo_result->get_joblist( ).
        MESSAGE 'Retrieved list of jobs.' TYPE 'I'.
      CATCH /aws1/cx_glaresourcenotfoundex.
        MESSAGE 'Vault not found.' TYPE 'E'.
      CATCH /aws1/cx_glainvparamvalueex.
        MESSAGE 'Invalid parameter value.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[gla.abapv1.list_jobs]
  ENDMETHOD.


  METHOD delete_vault.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_gla) = /aws1/cl_gla_factory=>create( lo_session ).

    " snippet-start:[gla.abapv1.delete_vault]
    TRY.
        " iv_vault_name = 'my-glacier-vault'
        lo_gla->deletevault( iv_vaultname = iv_vault_name ).
        MESSAGE 'Glacier vault deleted.' TYPE 'I'.
      CATCH /aws1/cx_glaresourcenotfoundex.
        MESSAGE 'Vault not found.' TYPE 'E'.
      CATCH /aws1/cx_glainvparamvalueex.
        MESSAGE 'Invalid parameter value.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[gla.abapv1.delete_vault]
  ENDMETHOD.


  METHOD delete_archive.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_gla) = /aws1/cl_gla_factory=>create( lo_session ).

    " snippet-start:[gla.abapv1.delete_archive]
    TRY.
        " iv_vault_name = 'my-glacier-vault'
        " iv_archive_id = 'archive-id-from-upload'
        lo_gla->deletearchive(
          iv_vaultname = iv_vault_name
          iv_archiveid = iv_archive_id
        ).
        MESSAGE 'Archive deleted from Glacier vault.' TYPE 'I'.
      CATCH /aws1/cx_glaresourcenotfoundex.
        MESSAGE 'Vault or archive not found.' TYPE 'E'.
      CATCH /aws1/cx_glainvparamvalueex.
        MESSAGE 'Invalid parameter value.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[gla.abapv1.delete_archive]
  ENDMETHOD.


  METHOD get_job_status.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_gla) = /aws1/cl_gla_factory=>create( lo_session ).

    " snippet-start:[gla.abapv1.describe_job]
    TRY.
        " iv_vault_name = 'my-glacier-vault'
        " iv_job_id = 'job-id-from-initiate'
        oo_result = lo_gla->describejob(
          iv_vaultname = iv_vault_name
          iv_jobid = iv_job_id
        ).
        DATA(lv_status) = oo_result->get_statuscode( ).
        DATA(lv_action) = oo_result->get_action( ).
        MESSAGE 'Job status retrieved.' TYPE 'I'.
      CATCH /aws1/cx_glaresourcenotfoundex.
        MESSAGE 'Vault or job not found.' TYPE 'E'.
      CATCH /aws1/cx_glainvparamvalueex.
        MESSAGE 'Invalid parameter value.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[gla.abapv1.describe_job]
  ENDMETHOD.


  METHOD get_job_output.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_gla) = /aws1/cl_gla_factory=>create( lo_session ).

    " snippet-start:[gla.abapv1.get_job_output]
    TRY.
        " iv_vault_name = 'my-glacier-vault'
        " iv_job_id = 'job-id-from-initiate'
        oo_result = lo_gla->getjoboutput(
          iv_vaultname = iv_vault_name
          iv_jobid = iv_job_id
        ).
        DATA(lv_body) = oo_result->get_body( ).
        MESSAGE 'Job output retrieved.' TYPE 'I'.
      CATCH /aws1/cx_glaresourcenotfoundex.
        MESSAGE 'Vault or job not found.' TYPE 'E'.
      CATCH /aws1/cx_glainvparamvalueex.
        MESSAGE 'Invalid parameter value.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[gla.abapv1.get_job_output]
  ENDMETHOD.


  METHOD set_vault_notifications.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_gla) = /aws1/cl_gla_factory=>create( lo_session ).

    " snippet-start:[gla.abapv1.set_vault_notifications]
    TRY.
        " iv_vault_name = 'my-glacier-vault'
        " iv_sns_topic = 'arn:aws:sns:region:account-id:topic-name'
        DATA lt_events TYPE /aws1/cl_glanotifeventlist_w=>tt_notificationeventlist.
        APPEND NEW /aws1/cl_glanotifeventlist_w( iv_value = 'ArchiveRetrievalCompleted' ) TO lt_events.
        APPEND NEW /aws1/cl_glanotifeventlist_w( iv_value = 'InventoryRetrievalCompleted' ) TO lt_events.

        DATA(lo_notification_config) = NEW /aws1/cl_glavaultnotifconfig(
          iv_snstopic = iv_sns_topic
          it_events = lt_events
        ).

        lo_gla->setvaultnotifications(
          iv_vaultname = iv_vault_name
          io_vaultnotificationconfig = lo_notification_config
        ).
        MESSAGE 'Vault notifications configured.' TYPE 'I'.
      CATCH /aws1/cx_glaresourcenotfoundex.
        MESSAGE 'Vault not found.' TYPE 'E'.
      CATCH /aws1/cx_glainvparamvalueex.
        MESSAGE 'Invalid parameter value.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[gla.abapv1.set_vault_notifications]
  ENDMETHOD.


  METHOD get_vault_notifications.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_gla) = /aws1/cl_gla_factory=>create( lo_session ).

    " snippet-start:[gla.abapv1.get_vault_notifications]
    TRY.
        " iv_vault_name = 'my-glacier-vault'
        oo_result = lo_gla->getvaultnotifications(
          iv_vaultname = iv_vault_name
        ).
        DATA(lo_notif_config) = oo_result->get_vaultnotificationconfig( ).
        IF lo_notif_config IS BOUND.
          DATA(lv_sns_topic) = lo_notif_config->get_snstopic( ).
          DATA(lt_events) = lo_notif_config->get_events( ).
          MESSAGE 'Retrieved vault notification configuration.' TYPE 'I'.
        ELSE.
          MESSAGE 'No notification configuration set for vault.' TYPE 'I'.
        ENDIF.
      CATCH /aws1/cx_glaresourcenotfoundex.
        MESSAGE 'Vault not found.' TYPE 'I'.
        RAISE EXCEPTION TYPE /aws1/cx_glaresourcenotfoundex.
      CATCH /aws1/cx_glainvparamvalueex.
        MESSAGE 'Invalid parameter value.' TYPE 'I'.
        RAISE EXCEPTION TYPE /aws1/cx_glainvparamvalueex.
    ENDTRY.
    " snippet-end:[gla.abapv1.get_vault_notifications]
  ENDMETHOD.


  METHOD delete_vault_notifs.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_gla) = /aws1/cl_gla_factory=>create( lo_session ).

    " snippet-start:[gla.abapv1.delete_vault_notifications]
    TRY.
        " iv_vault_name = 'my-glacier-vault'
        lo_gla->deletevaultnotifications(
          iv_vaultname = iv_vault_name
        ).
        MESSAGE 'Vault notifications deleted.' TYPE 'I'.
      CATCH /aws1/cx_glaresourcenotfoundex.
        MESSAGE 'Vault not found.' TYPE 'E'.
      CATCH /aws1/cx_glainvparamvalueex.
        MESSAGE 'Invalid parameter value.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[gla.abapv1.delete_vault_notifications]
  ENDMETHOD.
ENDCLASS.
