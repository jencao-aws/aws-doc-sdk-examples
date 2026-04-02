" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS /awsex/cl_s3c_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " Creates an S3 Batch Operations job to tag objects
    METHODS create_job
      IMPORTING
        !iv_account_id          TYPE /aws1/s3caccountid
        !iv_role_arn            TYPE /aws1/s3ciamrolearn
        !iv_manifest_bucket     TYPE /aws1/s3cbucketname
        !iv_manifest_key        TYPE string
        !iv_manifest_etag       TYPE string
        !iv_report_bucket       TYPE /aws1/s3cs3bucketarnstring
      RETURNING
        VALUE(oo_result)        TYPE REF TO /aws1/cl_s3ccreatejobresult
      RAISING
        /aws1/cx_rt_generic.

    " Updates the priority of an S3 Batch Operations job
    METHODS update_job_priority
      IMPORTING
        !iv_account_id     TYPE /aws1/s3caccountid
        !iv_job_id         TYPE /aws1/s3cjobid
        !iv_priority       TYPE /aws1/s3cjobpriority
      RETURNING
        VALUE(oo_result)   TYPE REF TO /aws1/cl_s3cupdjobpriorityrslt
      RAISING
        /aws1/cx_rt_generic.

    " Updates the status of an S3 Batch Operations job
    METHODS update_job_status
      IMPORTING
        !iv_account_id          TYPE /aws1/s3caccountid
        !iv_job_id              TYPE /aws1/s3cjobid
        !iv_requested_status    TYPE /aws1/s3crequestedjobstatus
      RETURNING
        VALUE(oo_result)        TYPE REF TO /aws1/cl_s3cupdjobstatusrslt
      RAISING
        /aws1/cx_rt_generic.

    " Retrieves details about an S3 Batch Operations job
    METHODS describe_job
      IMPORTING
        !iv_account_id     TYPE /aws1/s3caccountid
        !iv_job_id         TYPE /aws1/s3cjobid
      RETURNING
        VALUE(oo_result)   TYPE REF TO /aws1/cl_s3cdescribejobresult
      RAISING
        /aws1/cx_rt_generic.

    " Gets tags for an S3 Batch Operations job
    METHODS get_job_tagging
      IMPORTING
        !iv_account_id     TYPE /aws1/s3caccountid
        !iv_job_id         TYPE /aws1/s3cjobid
      RETURNING
        VALUE(oo_result)   TYPE REF TO /aws1/cl_s3cgetjobtagresult
      RAISING
        /aws1/cx_rt_generic.

    " Adds tags to an S3 Batch Operations job
    METHODS put_job_tagging
      IMPORTING
        !iv_account_id     TYPE /aws1/s3caccountid
        !iv_job_id         TYPE /aws1/s3cjobid
        !it_tags           TYPE /aws1/cl_s3cs3tag=>tt_s3tagset
      RETURNING
        VALUE(oo_result)   TYPE REF TO /aws1/cl_s3cputjobtagresult
      RAISING
        /aws1/cx_rt_generic.

    " Lists S3 Batch Operations jobs
    METHODS list_jobs
      IMPORTING
        !iv_account_id     TYPE /aws1/s3caccountid
        !it_job_statuses   TYPE /aws1/cl_s3cjobstatuslist_w=>tt_jobstatuslist OPTIONAL
      RETURNING
        VALUE(oo_result)   TYPE REF TO /aws1/cl_s3clistjobsresult
      RAISING
        /aws1/cx_rt_generic.

    " Deletes tags from an S3 Batch Operations job
    METHODS delete_job_tagging
      IMPORTING
        !iv_account_id     TYPE /aws1/s3caccountid
        !iv_job_id         TYPE /aws1/s3cjobid
      RETURNING
        VALUE(oo_result)   TYPE REF TO /aws1/cl_s3cdeletejobtagresult
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
    " Create manifest object
    DATA(lv_manifest_arn) = |arn:aws:s3:::{ iv_manifest_bucket }/{ iv_manifest_key }|.
    DATA(lo_manifest_location) = NEW /aws1/cl_s3cjobmanifestloc(
      iv_objectarn = lv_manifest_arn
      iv_etag      = iv_manifest_etag ).

    " e.g. iv_manifest_bucket = 'my-s3-batch-bucket'
    " e.g. iv_manifest_key = 'job-manifest.csv'
    " e.g. iv_manifest_etag = 'abc123def456'
    DATA(lo_manifest_spec) = NEW /aws1/cl_s3cjobmanifestspec(
      iv_format = 'S3BatchOperations_CSV_20180820' ).

    DATA lt_fields TYPE /aws1/cl_s3cjobmanifestfield00=>tt_jobmanifestfieldlist.
    APPEND NEW /aws1/cl_s3cjobmanifestfield00( iv_value = 'Bucket' ) TO lt_fields.
    APPEND NEW /aws1/cl_s3cjobmanifestfield00( iv_value = 'Key' ) TO lt_fields.
    lo_manifest_spec->set_fields( lt_fields ).

    DATA(lo_manifest) = NEW /aws1/cl_s3cjobmanifest(
      io_spec     = lo_manifest_spec
      io_location = lo_manifest_location ).

    " Create operation to tag objects
    DATA lt_tagset TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.
    APPEND NEW /aws1/cl_s3cs3tag(
      iv_key   = 'BatchTag'
      iv_value = 'BatchValue' ) TO lt_tagset.

    DATA(lo_operation) = NEW /aws1/cl_s3cjoboperation( ).
    lo_operation->set_s3putobjecttagging(
      NEW /aws1/cl_s3cs3setobjecttagop( it_tagset = lt_tagset ) ).

    " Create report configuration
    " e.g. iv_report_bucket = 'arn:aws:s3:::my-report-bucket'
    DATA(lo_report) = NEW /aws1/cl_s3cjobreport(
      iv_bucket      = iv_report_bucket
      iv_format      = 'Report_CSV_20180820'
      iv_enabled     = abap_true
      iv_prefix      = 'batch-op-reports'
      iv_reportscope = 'AllTasks' ).

    " e.g. iv_account_id = '123456789012'
    " e.g. iv_role_arn = 'arn:aws:iam::123456789012:role/S3BatchRole'
    TRY.
        oo_result = lo_s3c->createjob(
          iv_accountid             = iv_account_id
          io_operation             = lo_operation
          io_report                = lo_report
          io_manifest              = lo_manifest
          iv_priority              = 10
          iv_rolearn               = iv_role_arn
          iv_description           = 'Batch job for tagging objects'
          iv_confirmationrequired  = abap_true ).

        MESSAGE 'S3 Batch job created successfully' TYPE 'I'.
      CATCH /aws1/cx_s3cbadrequestex INTO DATA(lo_bad_request_ex).
        MESSAGE lo_bad_request_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3cidempotencyex INTO DATA(lo_idempotency_ex).
        MESSAGE lo_idempotency_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_service_ex).
        MESSAGE lo_service_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many_ex).
        MESSAGE lo_too_many_ex->get_text( ) TYPE 'I'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.create_job]
  ENDMETHOD.


  METHOD update_job_priority.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.update_job_priority]
    " e.g. iv_account_id = '123456789012'
    " e.g. iv_job_id = 'a1b2c3d4-5678-90ab-cdef-example11111'
    " e.g. iv_priority = 60
    TRY.
        oo_result = lo_s3c->updatejobpriority(
          iv_accountid = iv_account_id
          iv_jobid     = iv_job_id
          iv_priority  = iv_priority ).

        MESSAGE 'Job priority updated successfully' TYPE 'I'.
      CATCH /aws1/cx_s3cbadrequestex INTO DATA(lo_bad_request_ex).
        MESSAGE lo_bad_request_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_service_ex).
        MESSAGE lo_service_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found_ex).
        MESSAGE lo_not_found_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many_ex).
        MESSAGE lo_too_many_ex->get_text( ) TYPE 'I'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.update_job_priority]
  ENDMETHOD.


  METHOD update_job_status.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.update_job_status]
    " e.g. iv_account_id = '123456789012'
    " e.g. iv_job_id = 'a1b2c3d4-5678-90ab-cdef-example11111'
    " e.g. iv_requested_status = 'Cancelled' or 'Ready'
    TRY.
        oo_result = lo_s3c->updatejobstatus(
          iv_accountid         = iv_account_id
          iv_jobid             = iv_job_id
          iv_requestedjobstatus = iv_requested_status ).

        MESSAGE 'Job status updated successfully' TYPE 'I'.
      CATCH /aws1/cx_s3cbadrequestex INTO DATA(lo_bad_request_ex).
        MESSAGE lo_bad_request_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_service_ex).
        MESSAGE lo_service_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3cjobstatusexception INTO DATA(lo_job_status_ex).
        MESSAGE lo_job_status_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found_ex).
        MESSAGE lo_not_found_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many_ex).
        MESSAGE lo_too_many_ex->get_text( ) TYPE 'I'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.update_job_status]
  ENDMETHOD.


  METHOD describe_job.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.describe_job]
    " e.g. iv_account_id = '123456789012'
    " e.g. iv_job_id = 'a1b2c3d4-5678-90ab-cdef-example11111'
    TRY.
        oo_result = lo_s3c->describejob(
          iv_accountid = iv_account_id
          iv_jobid     = iv_job_id ).

        DATA(lo_job) = oo_result->get_job( ).
        DATA(lv_msg) = |Job Status: { lo_job->get_status( ) }|.
        MESSAGE lv_msg TYPE 'I'.
      CATCH /aws1/cx_s3cbadrequestex INTO DATA(lo_bad_request_ex).
        MESSAGE lo_bad_request_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_service_ex).
        MESSAGE lo_service_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found_ex).
        MESSAGE lo_not_found_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many_ex).
        MESSAGE lo_too_many_ex->get_text( ) TYPE 'I'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.describe_job]
  ENDMETHOD.


  METHOD get_job_tagging.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.get_job_tagging]
    " e.g. iv_account_id = '123456789012'
    " e.g. iv_job_id = 'a1b2c3d4-5678-90ab-cdef-example11111'
    TRY.
        oo_result = lo_s3c->getjobtagging(
          iv_accountid = iv_account_id
          iv_jobid     = iv_job_id ).

        DATA(lt_tags) = oo_result->get_tags( ).
        DATA(lv_tag_count) = lines( lt_tags ).
        DATA(lv_msg) = |Job has { lv_tag_count } tags|.
        MESSAGE lv_msg TYPE 'I'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_service_ex).
        MESSAGE lo_service_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found_ex).
        MESSAGE lo_not_found_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many_ex).
        MESSAGE lo_too_many_ex->get_text( ) TYPE 'I'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.get_job_tagging]
  ENDMETHOD.


  METHOD put_job_tagging.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.put_job_tagging]
    " e.g. iv_account_id = '123456789012'
    " e.g. iv_job_id = 'a1b2c3d4-5678-90ab-cdef-example11111'
    " e.g. it_tags contains tags like Environment=Development, Team=DataProcessing
    TRY.
        oo_result = lo_s3c->putjobtagging(
          iv_accountid = iv_account_id
          iv_jobid     = iv_job_id
          it_tags      = it_tags ).

        MESSAGE 'Job tags added successfully' TYPE 'I'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_service_ex).
        MESSAGE lo_service_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found_ex).
        MESSAGE lo_not_found_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many_ex).
        MESSAGE lo_too_many_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3ctoomanytagsex INTO DATA(lo_too_many_tags_ex).
        MESSAGE lo_too_many_tags_ex->get_text( ) TYPE 'I'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.put_job_tagging]
  ENDMETHOD.


  METHOD list_jobs.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.list_jobs]
    " e.g. iv_account_id = '123456789012'
    " e.g. it_job_statuses can contain 'Active', 'Complete', 'Cancelled', etc.
    TRY.
        oo_result = lo_s3c->listjobs(
          iv_accountid   = iv_account_id
          it_jobstatuses = it_job_statuses ).

        DATA(lt_jobs) = oo_result->get_jobs( ).
        DATA(lv_job_count) = lines( lt_jobs ).
        DATA(lv_msg) = |Found { lv_job_count } jobs|.
        MESSAGE lv_msg TYPE 'I'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_service_ex).
        MESSAGE lo_service_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3cinvalidnexttokenex INTO DATA(lo_invalid_token_ex).
        MESSAGE lo_invalid_token_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3cinvalidrequestex INTO DATA(lo_invalid_request_ex).
        MESSAGE lo_invalid_request_ex->get_text( ) TYPE 'I'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.list_jobs]
  ENDMETHOD.


  METHOD delete_job_tagging.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.delete_job_tagging]
    " e.g. iv_account_id = '123456789012'
    " e.g. iv_job_id = 'a1b2c3d4-5678-90ab-cdef-example11111'
    TRY.
        oo_result = lo_s3c->deletejobtagging(
          iv_accountid = iv_account_id
          iv_jobid     = iv_job_id ).

        MESSAGE 'Job tags deleted successfully' TYPE 'I'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_service_ex).
        MESSAGE lo_service_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found_ex).
        MESSAGE lo_not_found_ex->get_text( ) TYPE 'I'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many_ex).
        MESSAGE lo_too_many_ex->get_text( ) TYPE 'I'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.delete_job_tagging]
  ENDMETHOD.
ENDCLASS.
