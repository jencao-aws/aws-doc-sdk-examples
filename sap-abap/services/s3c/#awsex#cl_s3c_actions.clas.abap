" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0

CLASS /awsex/cl_s3c_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS create_job
      IMPORTING
        !iv_account_id         TYPE /aws1/s3caccountid
        !iv_role_arn           TYPE /aws1/s3ciamrolearn
        !iv_manifest_etag      TYPE string
        !iv_manifest_object_arn TYPE /aws1/s3cs3keyarnstring
        !iv_report_bucket      TYPE /aws1/s3cs3bucketarnstring
        !iv_operation_tag_key  TYPE /aws1/s3ctagkeystring DEFAULT 'BatchTag'
        !iv_operation_tag_value TYPE /aws1/s3ctagvaluestring DEFAULT 'BatchValue'
      EXPORTING
        !oo_result             TYPE REF TO /aws1/cl_s3ccreatejobresult
      RAISING
        /aws1/cx_rt_generic.

    METHODS describe_job
      IMPORTING
        !iv_account_id TYPE /aws1/s3caccountid
        !iv_job_id     TYPE /aws1/s3cjobid
      EXPORTING
        !oo_result     TYPE REF TO /aws1/cl_s3cdescribejobresult
      RAISING
        /aws1/cx_rt_generic.

    METHODS list_jobs
      IMPORTING
        !iv_account_id TYPE /aws1/s3caccountid
      EXPORTING
        !oo_result     TYPE REF TO /aws1/cl_s3clistjobsresult
      RAISING
        /aws1/cx_rt_generic.

    METHODS update_job_priority
      IMPORTING
        !iv_account_id TYPE /aws1/s3caccountid
        !iv_job_id     TYPE /aws1/s3cjobid
        !iv_priority   TYPE /aws1/s3cjobpriority DEFAULT 60
      EXPORTING
        !oo_result     TYPE REF TO /aws1/cl_s3cupdjobpriorityrslt
      RAISING
        /aws1/cx_rt_generic.

    METHODS update_job_status
      IMPORTING
        !iv_account_id          TYPE /aws1/s3caccountid
        !iv_job_id              TYPE /aws1/s3cjobid
        !iv_requested_job_status TYPE /aws1/s3crequestedjobstatus
      EXPORTING
        !oo_result              TYPE REF TO /aws1/cl_s3cupdjobstatusrslt
      RAISING
        /aws1/cx_rt_generic.

    METHODS get_job_tagging
      IMPORTING
        !iv_account_id TYPE /aws1/s3caccountid
        !iv_job_id     TYPE /aws1/s3cjobid
      EXPORTING
        !oo_result     TYPE REF TO /aws1/cl_s3cgetjobtagresult
      RAISING
        /aws1/cx_rt_generic.

    METHODS put_job_tagging
      IMPORTING
        !iv_account_id TYPE /aws1/s3caccountid
        !iv_job_id     TYPE /aws1/s3cjobid
      EXPORTING
        !oo_result     TYPE REF TO /aws1/cl_s3cputjobtagresult
      RAISING
        /aws1/cx_rt_generic.

    METHODS delete_job_tagging
      IMPORTING
        !iv_account_id TYPE /aws1/s3caccountid
        !iv_job_id     TYPE /aws1/s3cjobid
      EXPORTING
        !oo_result     TYPE REF TO /aws1/cl_s3cdeletejobtagresult
      RAISING
        /aws1/cx_rt_generic.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /AWSEX/CL_S3C_ACTIONS IMPLEMENTATION.


  METHOD create_job.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.create_job]
    TRY.
        " Create S3 Batch Operation job with tagging operation
        DATA lt_tagset TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.
        APPEND NEW /aws1/cl_s3cs3tag(
          iv_key = iv_operation_tag_key
          iv_value = iv_operation_tag_value ) TO lt_tagset.

        oo_result = lo_s3c->createjob(
          iv_accountid = iv_account_id
          iv_confirmationrequired = abap_true
          iv_priority = 10
          iv_rolearn = iv_role_arn
          iv_description = 'Batch job for tagging objects'
          io_operation = NEW /aws1/cl_s3cjoboperation(
            io_s3putobjecttagging = NEW /aws1/cl_s3cs3setobjecttagop(
              it_tagset = lt_tagset ) )
          io_report = NEW /aws1/cl_s3cjobreport(
            iv_bucket = iv_report_bucket
            iv_format = 'Report_CSV_20180820'
            iv_enabled = abap_true
            iv_prefix = 'batch-op-reports'
            iv_reportscope = 'AllTasks' )
          io_manifest = NEW /aws1/cl_s3cjobmanifest(
            io_spec = NEW /aws1/cl_s3cjobmanifestspec(
              iv_format = 'S3BatchOperations_CSV_20180820'
              it_fields = VALUE /aws1/cl_s3cjobmanifestfield00=>tt_jobmanifestfieldlist(
                ( NEW /aws1/cl_s3cjobmanifestfield00( 'Bucket' ) )
                ( NEW /aws1/cl_s3cjobmanifestfield00( 'Key' ) ) ) )
            io_location = NEW /aws1/cl_s3cjobmanifestloc(
              iv_objectarn = iv_manifest_object_arn
              iv_etag = iv_manifest_etag ) ) ).

        DATA(lv_job_id) = oo_result->get_jobid( ).
        MESSAGE |Job created with ID: { lv_job_id }| TYPE 'I'.
      CATCH /aws1/cx_s3cidempotencyex.
        MESSAGE 'Idempotency exception occurred.' TYPE 'E'.
      CATCH /aws1/cx_s3cinternalserviceex.
        MESSAGE 'Internal service exception occurred.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.create_job]
  ENDMETHOD.


  METHOD describe_job.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.describe_job]
    TRY.
        oo_result = lo_s3c->describejob(
          iv_accountid = iv_account_id
          iv_jobid = iv_job_id ).

        DATA(lo_job) = oo_result->get_job( ).
        IF lo_job IS BOUND.
          DATA(lv_status) = lo_job->get_status( ).
          DATA(lv_priority) = lo_job->get_priority( ).
          DATA(lv_description) = lo_job->get_description( ).

          DATA(lo_progress) = lo_job->get_progresssummary( ).
          IF lo_progress IS BOUND.
            DATA(lv_total) = lo_progress->get_totalnumberoftasks( ).
            DATA(lv_succeeded) = lo_progress->get_numberoftaskssucceeded( ).
            DATA(lv_failed) = lo_progress->get_numberoftasksfailed( ).
            MESSAGE |Job { iv_job_id } Status: { lv_status }, Progress: { lv_succeeded }/{ lv_total } succeeded| TYPE 'I'.
          ELSE.
            MESSAGE |Job { iv_job_id } Status: { lv_status }| TYPE 'I'.
          ENDIF.
        ENDIF.
      CATCH /aws1/cx_s3cnotfoundexception.
        MESSAGE 'Job not found.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.describe_job]
  ENDMETHOD.


  METHOD list_jobs.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.list_jobs]
    TRY.
        DATA lt_job_statuses TYPE /aws1/cl_s3cjobstatuslist_w=>tt_jobstatuslist.
        " Include multiple statuses to list jobs
        APPEND NEW /aws1/cl_s3cjobstatuslist_w( 'Active' ) TO lt_job_statuses.
        APPEND NEW /aws1/cl_s3cjobstatuslist_w( 'Complete' ) TO lt_job_statuses.
        APPEND NEW /aws1/cl_s3cjobstatuslist_w( 'Cancelled' ) TO lt_job_statuses.
        APPEND NEW /aws1/cl_s3cjobstatuslist_w( 'Failed' ) TO lt_job_statuses.
        APPEND NEW /aws1/cl_s3cjobstatuslist_w( 'Ready' ) TO lt_job_statuses.
        APPEND NEW /aws1/cl_s3cjobstatuslist_w( 'Suspended' ) TO lt_job_statuses.

        oo_result = lo_s3c->listjobs(
          iv_accountid = iv_account_id
          it_jobstatuses = lt_job_statuses ).

        DATA(lt_jobs) = oo_result->get_jobs( ).
        DATA(lv_job_count) = lines( lt_jobs ).
        MESSAGE |Found { lv_job_count } jobs| TYPE 'I'.
      CATCH /aws1/cx_s3cinvalidrequestex.
        MESSAGE 'Invalid request exception.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.list_jobs]
  ENDMETHOD.


  METHOD update_job_priority.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.update_job_priority]
    TRY.
        oo_result = lo_s3c->updatejobpriority(
          iv_accountid = iv_account_id
          iv_jobid = iv_job_id
          iv_priority = iv_priority ).

        DATA(lv_new_priority) = oo_result->get_priority( ).
        MESSAGE |Job priority updated to { lv_new_priority }| TYPE 'I'.
      CATCH /aws1/cx_s3cnotfoundexception.
        MESSAGE 'Job not found.' TYPE 'E'.
      CATCH /aws1/cx_s3cjobstatusexception.
        MESSAGE 'Job status does not allow priority update.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.update_job_priority]
  ENDMETHOD.


  METHOD update_job_status.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.update_job_status]
    TRY.
        oo_result = lo_s3c->updatejobstatus(
          iv_accountid = iv_account_id
          iv_jobid = iv_job_id
          iv_requestedjobstatus = iv_requested_job_status ).

        DATA(lv_updated_status) = oo_result->get_status( ).
        MESSAGE |Job status updated to { lv_updated_status }| TYPE 'I'.
      CATCH /aws1/cx_s3cnotfoundexception.
        MESSAGE 'Job not found.' TYPE 'E'.
      CATCH /aws1/cx_s3cjobstatusexception.
        MESSAGE 'Invalid job status transition.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.update_job_status]
  ENDMETHOD.


  METHOD get_job_tagging.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.get_job_tagging]
    TRY.
        oo_result = lo_s3c->getjobtagging(
          iv_accountid = iv_account_id
          iv_jobid = iv_job_id ).

        DATA(lt_tags) = oo_result->get_tags( ).
        DATA(lv_tag_count) = lines( lt_tags ).
        MESSAGE |Job has { lv_tag_count } tags| TYPE 'I'.
      CATCH /aws1/cx_s3cnotfoundexception.
        MESSAGE 'Job not found.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.get_job_tagging]
  ENDMETHOD.


  METHOD put_job_tagging.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.put_job_tagging]
    TRY.
        " Example tags: Environment=Development, Team=DataProcessing
        DATA lt_tags TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.
        APPEND NEW /aws1/cl_s3cs3tag( iv_key = 'Environment' iv_value = 'Development' ) TO lt_tags.
        APPEND NEW /aws1/cl_s3cs3tag( iv_key = 'Team' iv_value = 'DataProcessing' ) TO lt_tags.

        oo_result = lo_s3c->putjobtagging(
          iv_accountid = iv_account_id
          iv_jobid = iv_job_id
          it_tags = lt_tags ).

        MESSAGE 'Job tags added successfully.' TYPE 'I'.
      CATCH /aws1/cx_s3cnotfoundexception.
        MESSAGE 'Job not found.' TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanytagsex.
        MESSAGE 'Too many tags for job.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.put_job_tagging]
  ENDMETHOD.


  METHOD delete_job_tagging.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.delete_job_tagging]
    TRY.
        oo_result = lo_s3c->deletejobtagging(
          iv_accountid = iv_account_id
          iv_jobid = iv_job_id ).

        MESSAGE 'Job tags deleted successfully.' TYPE 'I'.
      CATCH /aws1/cx_s3cnotfoundexception.
        MESSAGE 'Job not found.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.delete_job_tagging]
  ENDMETHOD.
ENDCLASS.
