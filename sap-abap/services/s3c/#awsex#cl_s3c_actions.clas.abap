" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS /awsex/cl_s3c_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS create_job
      IMPORTING
        !iv_role_arn          TYPE /aws1/s3ciamrolearn
        !iv_manifest_location TYPE /aws1/s3cs3keyarnstring
        !iv_manifest_etag     TYPE /aws1/s3cnonemptymaxlength1000
        !iv_report_bucket     TYPE /aws1/s3cs3bucketarnstring
      RETURNING
        VALUE(ov_job_id)      TYPE /aws1/s3cjobid
      RAISING
        /aws1/cx_s3cbadrequestex
        /aws1/cx_s3cidempotencyex
        /aws1/cx_s3cinternalserviceex
        /aws1/cx_s3cinvalidrequestex
        /aws1/cx_s3ctoomanytagsex
        /aws1/cx_rt_generic .
    METHODS update_job_priority
      IMPORTING
        !iv_job_id       TYPE /aws1/s3cjobid
        !iv_priority     TYPE /aws1/s3cjobpriority
      RAISING
        /aws1/cx_s3cbadrequestex
        /aws1/cx_s3cinternalserviceex
        /aws1/cx_s3cinvalidrequestex
        /aws1/cx_s3cnotfoundexception
        /aws1/cx_s3ctoomanyrequestsex
        /aws1/cx_rt_generic .
    METHODS update_job_status
      IMPORTING
        !iv_job_id                TYPE /aws1/s3cjobid
        !iv_requested_job_status  TYPE /aws1/s3crequestedjobstatus
        !iv_status_update_reason  TYPE /aws1/s3cjobstatusupdatereason OPTIONAL
      RAISING
        /aws1/cx_s3cbadrequestex
        /aws1/cx_s3cinternalserviceex
        /aws1/cx_s3cinvalidrequestex
        /aws1/cx_s3cjobstatusexception
        /aws1/cx_s3cnotfoundexception
        /aws1/cx_s3ctoomanyrequestsex
        /aws1/cx_rt_generic .
    METHODS describe_job
      IMPORTING
        !iv_job_id        TYPE /aws1/s3cjobid
      EXPORTING
        !oo_result        TYPE REF TO /aws1/cl_s3cdescribejobresult
      RAISING
        /aws1/cx_s3cbadrequestex
        /aws1/cx_s3cinternalserviceex
        /aws1/cx_s3cinvalidrequestex
        /aws1/cx_s3cnotfoundexception
        /aws1/cx_s3ctoomanyrequestsex
        /aws1/cx_rt_generic .
    METHODS get_job_tagging
      IMPORTING
        !iv_job_id        TYPE /aws1/s3cjobid
      EXPORTING
        !oo_result        TYPE REF TO /aws1/cl_s3cgetjobtagresult
      RAISING
        /aws1/cx_s3cinternalserviceex
        /aws1/cx_s3cinvalidrequestex
        /aws1/cx_s3cnotfoundexception
        /aws1/cx_s3ctoomanyrequestsex
        /aws1/cx_rt_generic .
    METHODS put_job_tagging
      IMPORTING
        !iv_job_id        TYPE /aws1/s3cjobid
        !it_tags          TYPE /aws1/cl_s3cs3tag=>tt_s3tagset
      RAISING
        /aws1/cx_s3cinternalserviceex
        /aws1/cx_s3cinvalidrequestex
        /aws1/cx_s3cnotfoundexception
        /aws1/cx_s3ctoomanyrequestsex
        /aws1/cx_s3ctoomanytagsex
        /aws1/cx_rt_generic .
    METHODS list_jobs
      IMPORTING
        !it_job_statuses  TYPE /aws1/cl_s3cjobstatuslist_w=>tt_jobstatuslist OPTIONAL
        !iv_max_results   TYPE /aws1/s3cmaxresults OPTIONAL
        !iv_next_token    TYPE /aws1/s3cstringfornexttoken OPTIONAL
      EXPORTING
        !oo_result        TYPE REF TO /aws1/cl_s3clistjobsresult
      RAISING
        /aws1/cx_s3cinternalserviceex
        /aws1/cx_s3cinvalidnexttokenex
        /aws1/cx_s3cinvalidrequestex
        /aws1/cx_rt_generic .
    METHODS delete_job_tagging
      IMPORTING
        !iv_job_id        TYPE /aws1/s3cjobid
      RAISING
        /aws1/cx_s3cinternalserviceex
        /aws1/cx_s3cinvalidrequestex
        /aws1/cx_s3cnotfoundexception
        /aws1/cx_s3ctoomanyrequestsex
        /aws1/cx_rt_generic .
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
        DATA(lo_result) = lo_s3c->createjob(
          io_manifest = NEW /aws1/cl_s3cjobmanifest(
            io_location = NEW /aws1/cl_s3cjobmanifestloc(
              iv_etag = iv_manifest_etag
              iv_objectarn = iv_manifest_location
            )
            io_spec = NEW /aws1/cl_s3cjobmanifestspec(
              it_fields = VALUE /aws1/cl_s3cjobmanifestfield00=>tt_jobmanifestfieldlist(
                ( NEW /aws1/cl_s3cjobmanifestfield00( 'Bucket' ) )
                ( NEW /aws1/cl_s3cjobmanifestfield00( 'Key' ) )
              )
              iv_format = 'S3BatchOperations_CSV_20180820'
            )
          )
          io_operation = NEW /aws1/cl_s3cjoboperation(
            io_s3putobjecttagging = NEW /aws1/cl_s3cs3setobjecttagop(
              it_tagset = VALUE /aws1/cl_s3cs3tag=>tt_s3tagset(
                ( NEW /aws1/cl_s3cs3tag(
                    iv_key = 'BatchTag'
                    iv_value = 'BatchValue'
                  )
                )
              )
            )
          )
          io_report = NEW /aws1/cl_s3cjobreport(
            iv_bucket = iv_report_bucket
            iv_enabled = abap_true
            iv_format = 'Report_CSV_20180820'
            iv_prefix = 'batch-op-reports'
            iv_reportscope = 'AllTasks'
          )
          iv_confirmationrequired = abap_true
          iv_description = 'Batch job for tagging objects'
          iv_priority = 10
          iv_rolearn = iv_role_arn
        ).
        ov_job_id = lo_result->get_jobid( ).
        MESSAGE 'Job created successfully.' TYPE 'I'.
      CATCH /aws1/cx_s3cbadrequestex INTO DATA(lo_bad_request).
        MESSAGE lo_bad_request->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cidempotencyex INTO DATA(lo_idempotency).
        MESSAGE lo_idempotency->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinvalidrequestex INTO DATA(lo_invalid).
        MESSAGE lo_invalid->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanytagsex INTO DATA(lo_too_many_tags).
        MESSAGE lo_too_many_tags->get_text( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.create_job]
  ENDMETHOD.


  METHOD delete_job_tagging.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.delete_job_tagging]
    TRY.
        lo_s3c->deletejobtagging(
          iv_jobid = iv_job_id
        ).
        MESSAGE 'Job tags deleted successfully.' TYPE 'I'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinvalidrequestex INTO DATA(lo_invalid).
        MESSAGE lo_invalid->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found).
        MESSAGE lo_not_found->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many).
        MESSAGE lo_too_many->get_text( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.delete_job_tagging]
  ENDMETHOD.


  METHOD describe_job.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.describe_job]
    TRY.
        oo_result = lo_s3c->describejob(
          iv_jobid = iv_job_id
        ).
        DATA(lo_job) = oo_result->get_job( ).
        IF lo_job IS BOUND.
          DATA(lv_job_id) = lo_job->get_jobid( ).
          DATA(lv_description) = lo_job->get_description( ).
          DATA(lv_status) = lo_job->get_status( ).
          DATA(lv_priority) = lo_job->get_priority( ).
          MESSAGE |Job details retrieved: ID={ lv_job_id }, Status={ lv_status }, Priority={ lv_priority }| TYPE 'I'.
        ENDIF.
      CATCH /aws1/cx_s3cbadrequestex INTO DATA(lo_bad_request).
        MESSAGE lo_bad_request->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinvalidrequestex INTO DATA(lo_invalid).
        MESSAGE lo_invalid->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found).
        MESSAGE lo_not_found->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many).
        MESSAGE lo_too_many->get_text( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.describe_job]
  ENDMETHOD.


  METHOD get_job_tagging.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.get_job_tagging]
    TRY.
        oo_result = lo_s3c->getjobtagging(
          iv_jobid = iv_job_id
        ).
        DATA(lt_tags) = oo_result->get_tags( ).
        IF lt_tags IS NOT INITIAL.
          DATA(lv_tag_count) = lines( lt_tags ).
          MESSAGE |Retrieved { lv_tag_count } job tags| TYPE 'I'.
        ELSE.
          MESSAGE 'No tags found for this job.' TYPE 'I'.
        ENDIF.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinvalidrequestex INTO DATA(lo_invalid).
        MESSAGE lo_invalid->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found).
        MESSAGE lo_not_found->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many).
        MESSAGE lo_too_many->get_text( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.get_job_tagging]
  ENDMETHOD.


  METHOD list_jobs.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.list_jobs]
    TRY.
        oo_result = lo_s3c->listjobs(
          it_jobstatuses = it_job_statuses
          iv_maxresults = iv_max_results
          iv_nexttoken = iv_next_token
        ).
        DATA(lt_jobs) = oo_result->get_jobs( ).
        IF lt_jobs IS NOT INITIAL.
          DATA(lv_job_count) = lines( lt_jobs ).
          MESSAGE |Found { lv_job_count } jobs| TYPE 'I'.
        ELSE.
          MESSAGE 'No jobs found.' TYPE 'I'.
        ENDIF.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinvalidnexttokenex INTO DATA(lo_invalid_token).
        MESSAGE lo_invalid_token->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinvalidrequestex INTO DATA(lo_invalid).
        MESSAGE lo_invalid->get_text( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.list_jobs]
  ENDMETHOD.


  METHOD put_job_tagging.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.put_job_tagging]
    TRY.
        lo_s3c->putjobtagging(
          iv_jobid = iv_job_id
          it_tags = it_tags
        ).
        MESSAGE 'Job tags added successfully.' TYPE 'I'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinvalidrequestex INTO DATA(lo_invalid).
        MESSAGE lo_invalid->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found).
        MESSAGE lo_not_found->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many).
        MESSAGE lo_too_many->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanytagsex INTO DATA(lo_too_many_tags).
        MESSAGE lo_too_many_tags->get_text( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.put_job_tagging]
  ENDMETHOD.


  METHOD update_job_priority.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.update_job_priority]
    TRY.
        DATA(lo_result) = lo_s3c->updatejobpriority(
          iv_jobid = iv_job_id
          iv_priority = iv_priority
        ).
        DATA(lv_updated_priority) = lo_result->get_priority( ).
        MESSAGE |Job priority updated to { lv_updated_priority }| TYPE 'I'.
      CATCH /aws1/cx_s3cbadrequestex INTO DATA(lo_bad_request).
        MESSAGE lo_bad_request->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinvalidrequestex INTO DATA(lo_invalid).
        MESSAGE lo_invalid->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found).
        MESSAGE lo_not_found->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many).
        MESSAGE lo_too_many->get_text( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.update_job_priority]
  ENDMETHOD.


  METHOD update_job_status.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.update_job_status]
    TRY.
        DATA(lo_result) = lo_s3c->updatejobstatus(
          iv_jobid = iv_job_id
          iv_requestedjobstatus = iv_requested_job_status
          iv_statusupdatereason = iv_status_update_reason
        ).
        DATA(lv_updated_status) = lo_result->get_status( ).
        MESSAGE |Job status updated to { lv_updated_status }| TYPE 'I'.
      CATCH /aws1/cx_s3cbadrequestex INTO DATA(lo_bad_request).
        MESSAGE lo_bad_request->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinvalidrequestex INTO DATA(lo_invalid).
        MESSAGE lo_invalid->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cjobstatusexception INTO DATA(lo_job_status).
        MESSAGE lo_job_status->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found).
        MESSAGE lo_not_found->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many).
        MESSAGE lo_too_many->get_text( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.update_job_status]
  ENDMETHOD.
ENDCLASS.
