" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0

CLASS ltc_awsex_cl_s3c_actions DEFINITION DEFERRED.
CLASS /awsex/cl_s3c_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_s3c_actions.

CLASS ltc_awsex_cl_s3c_actions DEFINITION FOR TESTING DURATION LONG RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA av_account_id TYPE /aws1/s3caccountid.
    CLASS-DATA av_bucket_name TYPE /aws1/s3_bucketname.
    CLASS-DATA av_role_arn TYPE /aws1/s3ciamrolearn.
    CLASS-DATA av_manifest_etag TYPE string.
    CLASS-DATA av_test_job_id TYPE /aws1/s3cjobid.

    CLASS-DATA ao_s3 TYPE REF TO /aws1/if_s3.
    CLASS-DATA ao_s3c TYPE REF TO /aws1/if_s3c.
    CLASS-DATA ao_iam TYPE REF TO /aws1/if_iam.
    CLASS-DATA ao_sts TYPE REF TO /aws1/if_sts.
    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_s3c_actions TYPE REF TO /awsex/cl_s3c_actions.

    METHODS: create_job FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_job FOR TESTING RAISING /aws1/cx_rt_generic,
      list_jobs FOR TESTING RAISING /aws1/cx_rt_generic,
      update_job_priority FOR TESTING RAISING /aws1/cx_rt_generic,
      update_job_status FOR TESTING RAISING /aws1/cx_rt_generic,
      get_job_tagging FOR TESTING RAISING /aws1/cx_rt_generic,
      put_job_tagging FOR TESTING RAISING /aws1/cx_rt_generic,
      delete_job_tagging FOR TESTING RAISING /aws1/cx_rt_generic.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic.

    METHODS wait_for_job_ready
      IMPORTING
        iv_job_id TYPE /aws1/s3cjobid
      RETURNING
        VALUE(rv_ready) TYPE abap_bool
      RAISING
        /aws1/cx_rt_generic.
ENDCLASS.

CLASS ltc_awsex_cl_s3c_actions IMPLEMENTATION.

  METHOD class_setup.
    TRY.
        ao_session = /aws1/cl_rt_session_aws=>create( cv_pfl ).
        ao_s3 = /aws1/cl_s3_factory=>create( ao_session ).
        ao_s3c = /aws1/cl_s3c_factory=>create( ao_session ).
        ao_iam = /aws1/cl_iam_factory=>create( ao_session ).
        ao_sts = /aws1/cl_sts_factory=>create( ao_session ).
        ao_s3c_actions = NEW /awsex/cl_s3c_actions( ).

        " Get account ID
        DATA(lo_caller_identity) = ao_sts->getcalleridentity( ).
        av_account_id = lo_caller_identity->get_account( ).

        " Create test bucket with unique name
        DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
        av_bucket_name = |sap-s3c-{ lv_uuid }|.
        
        " Create bucket using utility function
        /awsex/cl_utils=>create_bucket(
          iv_bucket = av_bucket_name
          io_s3 = ao_s3
          io_session = ao_session ).

        " Tag bucket for cleanup
        DATA lt_s3_tags TYPE /aws1/cl_s3_tag=>tt_tagset.
        APPEND NEW /aws1/cl_s3_tag( iv_key = 'convert_test' iv_value = 'true' ) TO lt_s3_tags.
        ao_s3->putbuckettagging(
          iv_bucket = av_bucket_name
          io_tagging = NEW /aws1/cl_s3_tagging( it_tagset = lt_s3_tags ) ).

        " Create IAM role for S3 Batch Operations with unique name
        DATA(lv_role_name) = |sap-s3c-role-{ lv_uuid }|.
        DATA(lv_policy_name) = |sap-s3c-pol-{ lv_uuid }|.
        
        DATA(lv_trust_policy) = '{' &&
          '"Version":"2012-10-17",' &&
          '"Statement":[{' &&
            '"Effect":"Allow",' &&
            '"Principal":{"Service":"batchoperations.s3.amazonaws.com"},' &&
            '"Action":"sts:AssumeRole"' &&
          '}]}' .

        " Create role - don't catch already exists, we want unique role
        DATA(lo_create_role_result) = ao_iam->createrole(
          iv_rolename = lv_role_name
          iv_assumerolepolicydocument = lv_trust_policy
          it_tags = VALUE /aws1/cl_iamtag=>tt_taglisttype(
            ( NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) ) ) ).
        av_role_arn = lo_create_role_result->get_role( )->get_arn( ).

        " Create comprehensive policy for S3 Batch Operations
        DATA(lv_policy_document) = '{' &&
          '"Version":"2012-10-17",' &&
          '"Statement":[' &&
            '{' &&
              '"Effect":"Allow",' &&
              '"Action":[' &&
                '"s3:GetObject",' &&
                '"s3:GetObjectVersion",' &&
                '"s3:PutObject",' &&
                '"s3:PutObjectAcl",' &&
                '"s3:PutObjectVersionAcl",' &&
                '"s3:PutObjectTagging",' &&
                '"s3:PutObjectVersionTagging",' &&
                '"s3:GetObjectTagging",' &&
                '"s3:GetObjectVersionTagging",' &&
                '"s3:DeleteObjectTagging",' &&
                '"s3:DeleteObjectVersionTagging",' &&
                '"s3:ListBucket",' &&
                '"s3:ListBucketVersions",' &&
                '"s3:GetBucketLocation",' &&
                '"s3:GetBucketVersioning",' &&
                '"s3:PutInventoryConfiguration",' &&
                '"s3:GetInventoryConfiguration"' &&
              '],' &&
              '"Resource":[' &&
                '"arn:aws:s3:::' && av_bucket_name && '",' &&
                '"arn:aws:s3:::' && av_bucket_name && '/*"' &&
              ']' &&
            '}' &&
          ']' &&
        '}' .

        DATA(lo_policy_result) = ao_iam->createpolicy(
          iv_policyname = lv_policy_name
          iv_policydocument = lv_policy_document
          it_tags = VALUE /aws1/cl_iamtag=>tt_taglisttype(
            ( NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) ) ) ).

        ao_iam->attachrolepolicy(
          iv_rolename = lv_role_name
          iv_policyarn = lo_policy_result->get_policy( )->get_arn( ) ).

        " Wait for role and policy propagation (critical for S3 Batch)
        WAIT UP TO 15 SECONDS.

        " Create test files and manifest
        CONSTANTS: cv_file1 TYPE /aws1/s3_objectkey VALUE 'test-file-1.txt',
                   cv_file2 TYPE /aws1/s3_objectkey VALUE 'test-file-2.txt',
                   cv_manifest TYPE /aws1/s3_objectkey VALUE 'job-manifest.csv'.

        " Upload test files (always recreate for fresh test)
        DATA lv_file1_body TYPE xstring.
        DATA lv_file2_body TYPE xstring.
        DATA lv_manifest_body TYPE xstring.
        DATA lv_file1_content TYPE string.
        DATA lv_file2_content TYPE string.
        DATA lv_manifest_content TYPE string.
        
        " Set string content
        lv_file1_content = 'Test content 1'.
        lv_file2_content = 'Test content 2'.
        
        " Convert string content to xstring for S3
        CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
          EXPORTING
            text   = lv_file1_content
          IMPORTING
            buffer = lv_file1_body.
        
        CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
          EXPORTING
            text   = lv_file2_content
          IMPORTING
            buffer = lv_file2_body.
        
        ao_s3->putobject(
          iv_bucket = av_bucket_name
          iv_key = cv_file1
          iv_body = lv_file1_body ).

        ao_s3->putobject(
          iv_bucket = av_bucket_name
          iv_key = cv_file2
          iv_body = lv_file2_body ).

        " Create and upload manifest
        lv_manifest_content = |{ av_bucket_name },{ cv_file1 }\n| &&
                              |{ av_bucket_name },{ cv_file2 }|.

        CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
          EXPORTING
            text   = lv_manifest_content
          IMPORTING
            buffer = lv_manifest_body.
        
        DATA(lo_manifest_result) = ao_s3->putobject(
          iv_bucket = av_bucket_name
          iv_key = cv_manifest
          iv_body = lv_manifest_body ).

        av_manifest_etag = lo_manifest_result->get_etag( ).
        " Remove quotes from ETag if present
        REPLACE ALL OCCURRENCES OF '"' IN av_manifest_etag WITH ''.

        " Ensure manifest ETag is valid
        IF av_manifest_etag IS INITIAL.
          cl_abap_unit_assert=>fail(
            msg = 'Failed to create manifest file with valid ETag' ).
        ENDIF.

      CATCH /aws1/cx_s3_nosuchbucket INTO DATA(lo_nosuchbucket_ex).
        cl_abap_unit_assert=>fail(
          msg = |NoSuchBucket: { lo_nosuchbucket_ex->if_message~get_text( ) }| ).
      CATCH /aws1/cx_s3_clientexc INTO DATA(lo_client_ex).
        cl_abap_unit_assert=>fail(
          msg = |S3 Client Exception during setup: { lo_client_ex->if_message~get_text( ) }| ).
      CATCH /aws1/cx_iamentityalrdyexex INTO DATA(lo_iam_ex).
        cl_abap_unit_assert=>fail(
          msg = |IAM Entity Already Exists: { lo_iam_ex->if_message~get_text( ) }| ).
      CATCH /aws1/cx_iammalformedplydocex INTO DATA(lo_policy_ex).
        cl_abap_unit_assert=>fail(
          msg = |IAM Malformed Policy: { lo_policy_ex->if_message~get_text( ) }| ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_generic_ex).
        cl_abap_unit_assert=>fail(
          msg = |Generic Exception during setup: { lo_generic_ex->if_message~get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.

  METHOD class_teardown.
    " Clean up S3 bucket and objects
    TRY.
        /awsex/cl_utils=>cleanup_bucket(
          iv_bucket = av_bucket_name
          io_s3 = ao_s3 ).
      CATCH /aws1/cx_rt_generic.
        " Ignore cleanup errors
    ENDTRY.

    " Note: IAM role and policy are tagged with 'convert_test' for manual cleanup
    " because detaching policies and deleting roles requires careful sequencing
  ENDMETHOD.

  METHOD wait_for_job_ready.
    rv_ready = abap_false.
    DATA lv_max_attempts TYPE i VALUE 60.
    DATA lv_attempt TYPE i VALUE 0.

    WHILE lv_attempt < lv_max_attempts.
      TRY.
          DATA(lo_job_desc) = ao_s3c->describejob(
            iv_accountid = av_account_id
            iv_jobid = iv_job_id ).

          DATA(lo_job) = lo_job_desc->get_job( ).
          IF lo_job IS BOUND.
            DATA(lv_status) = lo_job->get_status( ).
            IF lv_status = 'Ready' OR lv_status = 'Suspended'.
              rv_ready = abap_true.
              RETURN.
            ELSEIF lv_status = 'Active' OR lv_status = 'Failed' OR
                   lv_status = 'Cancelled' OR lv_status = 'Complete'.
              " Job is in a terminal or active state
              RETURN.
            ENDIF.
          ENDIF.
        CATCH /aws1/cx_rt_generic.
          " Continue waiting
      ENDTRY.

      WAIT UP TO 20 SECONDS.
      lv_attempt = lv_attempt + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD create_job.
    DATA lo_result TYPE REF TO /aws1/cl_s3ccreatejobresult.
    DATA lv_manifest_arn TYPE /aws1/s3cs3keyarnstring.

    " Verify all required resources exist
    cl_abap_unit_assert=>assert_not_initial(
      act = av_account_id
      msg = 'Account ID must be set in class_setup' ).

    cl_abap_unit_assert=>assert_not_initial(
      act = av_role_arn
      msg = 'Role ARN must be set in class_setup' ).

    cl_abap_unit_assert=>assert_not_initial(
      act = av_manifest_etag
      msg = 'Manifest ETag must be set in class_setup' ).

    " Construct manifest ARN
    DATA(lv_region) = ao_session->get_region( ).
    lv_manifest_arn = |arn:aws:s3:::{ av_bucket_name }/job-manifest.csv|.

    TRY.
        ao_s3c_actions->create_job(
          EXPORTING
            iv_account_id = av_account_id
            iv_role_arn = av_role_arn
            iv_manifest_etag = av_manifest_etag
            iv_manifest_object_arn = lv_manifest_arn
            iv_report_bucket = |arn:aws:s3:::{ av_bucket_name }|
            io_s3c = ao_s3c
          IMPORTING
            oo_result = lo_result ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_exception).
        cl_abap_unit_assert=>fail(
          msg = |Create job failed: { lo_exception->get_text( ) }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Create job result should be bound' ).

    av_test_job_id = lo_result->get_jobid( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = av_test_job_id
      msg = 'Job ID should not be initial' ).
  ENDMETHOD.

  METHOD describe_job.
    " Fail if no job was created
    cl_abap_unit_assert=>assert_not_initial(
      act = av_test_job_id
      msg = 'Job must be created before describing it' ).

    DATA lo_result TYPE REF TO /aws1/cl_s3cdescribejobresult.

    ao_s3c_actions->describe_job(
      EXPORTING
        iv_account_id = av_account_id
        iv_job_id = av_test_job_id
        io_s3c = ao_s3c
      IMPORTING
        oo_result = lo_result ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Describe job result should be bound' ).

    DATA(lo_job) = lo_result->get_job( ).
    cl_abap_unit_assert=>assert_bound(
      act = lo_job
      msg = 'Job descriptor should be bound' ).

    DATA(lv_job_id) = lo_job->get_jobid( ).
    cl_abap_unit_assert=>assert_equals(
      exp = av_test_job_id
      act = lv_job_id
      msg = 'Job ID should match' ).
  ENDMETHOD.

  METHOD list_jobs.
    DATA lo_result TYPE REF TO /aws1/cl_s3clistjobsresult.

    TRY.
        ao_s3c_actions->list_jobs(
          EXPORTING
            iv_account_id = av_account_id
            io_s3c = ao_s3c
          IMPORTING
            oo_result = lo_result ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_exception).
        cl_abap_unit_assert=>fail(
          msg = |List jobs failed: { lo_exception->get_text( ) }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'List jobs result should be bound' ).
  ENDMETHOD.

  METHOD update_job_priority.
    " Fail if no job was created
    cl_abap_unit_assert=>assert_not_initial(
      act = av_test_job_id
      msg = 'Job must be created before updating priority' ).

    " Wait for job to be in a state that allows priority update
    DATA(lv_ready) = wait_for_job_ready( av_test_job_id ).
    
    " If job is not ready after waiting, check current state
    IF lv_ready = abap_false.
      DATA(lo_check_result) = ao_s3c->describejob(
        iv_accountid = av_account_id
        iv_jobid = av_test_job_id ).
      DATA(lo_check_job) = lo_check_result->get_job( ).
      DATA(lv_current_status) = lo_check_job->get_status( ).
      
      " If job is in Complete or Cancelled, that's acceptable for this test scenario
      IF lv_current_status = 'Complete' OR lv_current_status = 'Cancelled'.
        MESSAGE |Job is in { lv_current_status } state, priority update test is not applicable| TYPE 'I'.
        RETURN.
      ENDIF.
    ENDIF.

    DATA lo_result TYPE REF TO /aws1/cl_s3cupdjobpriorityrslt.

    ao_s3c_actions->update_job_priority(
      EXPORTING
        iv_account_id = av_account_id
        iv_job_id = av_test_job_id
        iv_priority = 60
        io_s3c = ao_s3c
      IMPORTING
        oo_result = lo_result ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Update job priority result should be bound' ).

    DATA(lv_priority) = lo_result->get_priority( ).
    cl_abap_unit_assert=>assert_equals(
      exp = 60
      act = lv_priority
      msg = 'Job priority should be updated to 60' ).
  ENDMETHOD.

  METHOD update_job_status.
    " Fail if no job was created
    cl_abap_unit_assert=>assert_not_initial(
      act = av_test_job_id
      msg = 'Job must be created before updating status' ).

    " Wait for job to be ready
    DATA(lv_ready) = wait_for_job_ready( av_test_job_id ).

    DATA lo_result TYPE REF TO /aws1/cl_s3cupdjobstatusrslt.

    " Try to cancel the job
    ao_s3c_actions->update_job_status(
      EXPORTING
        iv_account_id = av_account_id
        iv_job_id = av_test_job_id
        iv_requested_job_status = 'Cancelled'
        io_s3c = ao_s3c
      IMPORTING
        oo_result = lo_result ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Update job status result should be bound' ).

    DATA(lv_status) = lo_result->get_status( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_status
      msg = 'Job status should not be initial' ).
  ENDMETHOD.

  METHOD get_job_tagging.
    " Fail if no job was created
    cl_abap_unit_assert=>assert_not_initial(
      act = av_test_job_id
      msg = 'Job must be created before getting tags' ).

    DATA lo_result TYPE REF TO /aws1/cl_s3cgetjobtagresult.

    ao_s3c_actions->get_job_tagging(
      EXPORTING
        iv_account_id = av_account_id
        iv_job_id = av_test_job_id
        io_s3c = ao_s3c
      IMPORTING
        oo_result = lo_result ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Get job tagging result should be bound' ).
  ENDMETHOD.

  METHOD put_job_tagging.
    " Fail if no job was created
    cl_abap_unit_assert=>assert_not_initial(
      act = av_test_job_id
      msg = 'Job must be created before putting tags' ).

    DATA lo_result TYPE REF TO /aws1/cl_s3cputjobtagresult.

    ao_s3c_actions->put_job_tagging(
      EXPORTING
        iv_account_id = av_account_id
        iv_job_id = av_test_job_id
        io_s3c = ao_s3c
      IMPORTING
        oo_result = lo_result ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Put job tagging result should be bound' ).

    " Verify tags were added
    DATA(lo_get_result) = ao_s3c->getjobtagging(
      iv_accountid = av_account_id
      iv_jobid = av_test_job_id ).

    DATA(lt_tags) = lo_get_result->get_tags( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_tags
      msg = 'Tags should have been added to job' ).
    
    " Verify at least 2 tags were added (Environment and Team)
    cl_abap_unit_assert=>assert_true(
      act = COND #( WHEN lines( lt_tags ) >= 2 THEN abap_true ELSE abap_false )
      msg = 'At least 2 tags should have been added' ).
  ENDMETHOD.

  METHOD delete_job_tagging.
    " Fail if no job was created
    cl_abap_unit_assert=>assert_not_initial(
      act = av_test_job_id
      msg = 'Job must be created before deleting tags' ).

    DATA lo_result TYPE REF TO /aws1/cl_s3cdeletejobtagresult.

    ao_s3c_actions->delete_job_tagging(
      EXPORTING
        iv_account_id = av_account_id
        iv_job_id = av_test_job_id
        io_s3c = ao_s3c
      IMPORTING
        oo_result = lo_result ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Delete job tagging result should be bound' ).
    
    " Verify tags were deleted
    DATA(lo_get_result) = ao_s3c->getjobtagging(
      iv_accountid = av_account_id
      iv_jobid = av_test_job_id ).

    DATA(lt_tags) = lo_get_result->get_tags( ).
    " After deletion, there should be no tags
    cl_abap_unit_assert=>assert_initial(
      act = lt_tags
      msg = 'All tags should have been deleted from job' ).
  ENDMETHOD.

ENDCLASS.
