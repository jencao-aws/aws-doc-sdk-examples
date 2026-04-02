" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS ltc_awsex_cl_s3c_actions DEFINITION DEFERRED.
CLASS /awsex/cl_s3c_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_s3c_actions.

CLASS ltc_awsex_cl_s3c_actions DEFINITION FOR TESTING DURATION LONG RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA gv_account_id TYPE /aws1/s3caccountid.
    CLASS-DATA gv_bucket_name TYPE /aws1/s3cbucketname.
    CLASS-DATA gv_manifest_bucket TYPE /aws1/s3cbucketname.
    CLASS-DATA gv_report_bucket_arn TYPE /aws1/s3cs3bucketarnstring.
    CLASS-DATA gv_role_arn TYPE /aws1/s3ciamrolearn.
    CLASS-DATA gv_role_name TYPE /aws1/iamrolenametype.
    CLASS-DATA gv_policy_arn TYPE /aws1/iamarntype.
    CLASS-DATA gv_job_id TYPE /aws1/s3cjobid.
    CLASS-DATA gv_uuid TYPE string.

    CLASS-DATA go_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA go_s3 TYPE REF TO /aws1/if_s3.
    CLASS-DATA go_s3c TYPE REF TO /aws1/if_s3c.
    CLASS-DATA go_iam TYPE REF TO /aws1/if_iam.
    CLASS-DATA go_sts TYPE REF TO /aws1/if_sts.
    CLASS-DATA go_s3c_actions TYPE REF TO /awsex/cl_s3c_actions.

    METHODS: create_job FOR TESTING RAISING /aws1/cx_rt_generic,
      update_job_priority FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_job FOR TESTING RAISING /aws1/cx_rt_generic,
      get_job_tagging FOR TESTING RAISING /aws1/cx_rt_generic,
      put_job_tagging FOR TESTING RAISING /aws1/cx_rt_generic,
      list_jobs FOR TESTING RAISING /aws1/cx_rt_generic,
      delete_job_tagging FOR TESTING RAISING /aws1/cx_rt_generic,
      update_job_status FOR TESTING RAISING /aws1/cx_rt_generic.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic /awsex/cx_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic /awsex/cx_generic.

    CLASS-METHODS create_iam_role
      RAISING /aws1/cx_rt_generic.

    CLASS-METHODS create_test_buckets
      RAISING /aws1/cx_rt_generic.

    CLASS-METHODS create_manifest_and_files
      RAISING /aws1/cx_rt_generic.

    METHODS wait_for_job_status
      IMPORTING
        iv_job_id         TYPE /aws1/s3cjobid
        iv_desired_status TYPE string
        iv_max_attempts   TYPE i DEFAULT 60
      RETURNING
        VALUE(rv_success) TYPE abap_bool
      RAISING
        /aws1/cx_rt_generic.

    METHODS ensure_job_exists
      RAISING /aws1/cx_rt_generic.
ENDCLASS.

CLASS ltc_awsex_cl_s3c_actions IMPLEMENTATION.

  METHOD class_setup.
    " Initialize AWS clients
    go_session = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    go_s3 = /aws1/cl_s3_factory=>create( go_session ).
    go_s3c = /aws1/cl_s3c_factory=>create( go_session ).
    go_iam = /aws1/cl_iam_factory=>create( go_session ).
    go_sts = /aws1/cl_sts_factory=>create( go_session ).
    go_s3c_actions = NEW /awsex/cl_s3c_actions( ).

    " Get account ID from STS - this is required and must not fail
    TRY.
        gv_account_id = go_sts->getcalleridentity( )->get_account( ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Failed to get account ID: { lo_ex->get_text( ) }| ).
    ENDTRY.

    " Generate unique identifier for all resources
    gv_uuid = /awsex/cl_utils=>get_random_string( ).

    " Create all test resources in proper order
    create_test_buckets( ).
    create_manifest_and_files( ).
    create_iam_role( ).

    " Set report bucket ARN
    gv_report_bucket_arn = |arn:aws:s3:::{ gv_manifest_bucket }|.
  ENDMETHOD.

  METHOD create_test_buckets.
    " Create unique bucket names
    gv_bucket_name = |sap-abap-s3c-test-{ gv_uuid }|.
    gv_bucket_name = to_lower( gv_bucket_name ).
    gv_manifest_bucket = |sap-abap-s3c-manifest-{ gv_uuid }|.
    gv_manifest_bucket = to_lower( gv_manifest_bucket ).

    " Create buckets - must succeed or fail test
    TRY.
        /awsex/cl_utils=>create_bucket(
          iv_bucket   = gv_bucket_name
          io_s3       = go_s3
          io_session  = go_session ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Failed to create bucket { gv_bucket_name }: { lo_ex->get_text( ) }| ).
    ENDTRY.

    TRY.
        /awsex/cl_utils=>create_bucket(
          iv_bucket   = gv_manifest_bucket
          io_s3       = go_s3
          io_session  = go_session ).
      CATCH /aws1/cx_rt_generic INTO lo_ex.
        cl_abap_unit_assert=>fail( msg = |Failed to create manifest bucket { gv_manifest_bucket }: { lo_ex->get_text( ) }| ).
    ENDTRY.

    " Tag buckets with convert_test tag
    DATA lt_tags TYPE /aws1/cl_s3_tag=>tt_tagset.
    APPEND NEW /aws1/cl_s3_tag( iv_key = 'convert_test' iv_value = 'true' ) TO lt_tags.

    TRY.
        go_s3->putbuckettagging(
          iv_bucket   = gv_bucket_name
          io_tagging  = NEW /aws1/cl_s3_tagging( it_tagset = lt_tags ) ).

        go_s3->putbuckettagging(
          iv_bucket   = gv_manifest_bucket
          io_tagging  = NEW /aws1/cl_s3_tagging( it_tagset = lt_tags ) ).
      CATCH /aws1/cx_rt_generic INTO lo_ex.
        " Log but don't fail on tagging errors
        MESSAGE lo_ex->get_text( ) TYPE 'I'.
    ENDTRY.
  ENDMETHOD.

  METHOD create_manifest_and_files.
    " Upload sample files to the bucket for batch operations
    DATA(lv_file1_content) = 'Sample content for file 1'.
    DATA(lv_file2_content) = 'Sample content for file 2'.
    DATA(lv_file3_content) = 'Sample content for file 3'.

    TRY.
        go_s3->putobject(
          iv_bucket = gv_bucket_name
          iv_key    = 'file1.txt'
          iv_body   = lv_file1_content ).

        go_s3->putobject(
          iv_bucket = gv_bucket_name
          iv_key    = 'file2.txt'
          iv_body   = lv_file2_content ).

        go_s3->putobject(
          iv_bucket = gv_bucket_name
          iv_key    = 'file3.txt'
          iv_body   = lv_file3_content ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Failed to upload test files: { lo_ex->get_text( ) }| ).
    ENDTRY.

    " Create and upload manifest file
    DATA(lv_manifest_content) = |{ gv_bucket_name },file1.txt\n| &&
                                 |{ gv_bucket_name },file2.txt\n| &&
                                 |{ gv_bucket_name },file3.txt\n|.

    TRY.
        go_s3->putobject(
          iv_bucket = gv_manifest_bucket
          iv_key    = 'job-manifest.csv'
          iv_body   = lv_manifest_content ).
      CATCH /aws1/cx_rt_generic INTO lo_ex.
        cl_abap_unit_assert=>fail( msg = |Failed to upload manifest file: { lo_ex->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD create_iam_role.
    " Create IAM role for S3 Batch Operations with all necessary permissions
    gv_role_name = |S3BatchRole{ gv_uuid }|.

    " Create assume role policy for S3 Batch Operations
    DATA(lv_assume_role_policy) = '{"Version":"2012-10-17","Statement":[{' &&
      '"Effect":"Allow",' &&
      '"Principal":{"Service":"batchoperations.s3.amazonaws.com"},' &&
      '"Action":"sts:AssumeRole"}]}'.

    TRY.
        DATA(lo_create_role) = go_iam->createrole(
          iv_rolename                 = gv_role_name
          iv_assumerolepolicydocument = lv_assume_role_policy
          iv_description              = 'Role for S3 Batch Operations testing' ).
        gv_role_arn = lo_create_role->get_role( )->get_arn( ).

      CATCH /aws1/cx_iamentityalrdyexists.
        " Role already exists from previous failed run, get the ARN
        TRY.
            DATA(lo_get_role) = go_iam->getrole( iv_rolename = gv_role_name ).
            gv_role_arn = lo_get_role->get_role( )->get_arn( ).
          CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
            cl_abap_unit_assert=>fail( msg = |Failed to get existing role: { lo_ex->get_text( ) }| ).
        ENDTRY.
      CATCH /aws1/cx_rt_generic INTO lo_ex.
        cl_abap_unit_assert=>fail( msg = |Failed to create IAM role: { lo_ex->get_text( ) }| ).
    ENDTRY.

    " Tag the role with convert_test tag
    DATA lt_iam_tags TYPE /aws1/cl_iamtag=>tt_taglisttype.
    APPEND NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) TO lt_iam_tags.

    TRY.
        go_iam->tagrole(
          iv_rolename = gv_role_name
          it_tags     = lt_iam_tags ).
      CATCH /aws1/cx_rt_generic INTO lo_ex.
        " Log but don't fail on tagging errors
        MESSAGE lo_ex->get_text( ) TYPE 'I'.
    ENDTRY.

    " Create comprehensive policy for S3 Batch Operations
    " This policy grants all necessary permissions for batch operations
    DATA(lv_policy_doc) = '{"Version":"2012-10-17","Statement":[' &&
      '{' &&
      '"Effect":"Allow",' &&
      '"Action":[' &&
        '"s3:GetObject",' &&
        '"s3:GetObjectVersion",' &&
        '"s3:PutObjectTagging",' &&
        '"s3:PutObjectVersionTagging",' &&
        '"s3:GetObjectTagging",' &&
        '"s3:GetObjectVersionTagging",' &&
        '"s3:DeleteObjectTagging",' &&
        '"s3:DeleteObjectVersionTagging"' &&
      '],' &&
      '"Resource":"arn:aws:s3:::*/*"' &&
      '},' &&
      '{' &&
      '"Effect":"Allow",' &&
      '"Action":[' &&
        '"s3:GetBucketLocation",' &&
        '"s3:ListBucket",' &&
        '"s3:ListBucketVersions"' &&
      '],' &&
      '"Resource":"arn:aws:s3:::*"' &&
      '},' &&
      '{' &&
      '"Effect":"Allow",' &&
      '"Action":["s3:PutObject"],' &&
      '"Resource":"arn:aws:s3:::' && gv_manifest_bucket && '/*"' &&
      '}]}'.

    DATA(lv_policy_name) = |S3BatchPolicy{ gv_uuid }|.

    TRY.
        DATA(lo_create_policy) = go_iam->createpolicy(
          iv_policyname     = lv_policy_name
          iv_policydocument = lv_policy_doc
          iv_description    = 'Policy for S3 Batch Operations' ).
        gv_policy_arn = lo_create_policy->get_policy( )->get_arn( ).

      CATCH /aws1/cx_iamentityalrdyexists.
        " Policy already exists, construct ARN manually
        gv_policy_arn = |arn:aws:iam::{ gv_account_id }:policy/{ lv_policy_name }|.

      CATCH /aws1/cx_rt_generic INTO lo_ex.
        cl_abap_unit_assert=>fail( msg = |Failed to create IAM policy: { lo_ex->get_text( ) }| ).
    ENDTRY.

    " Attach policy to role
    TRY.
        go_iam->attachrolepolicy(
          iv_rolename  = gv_role_name
          iv_policyarn = gv_policy_arn ).
      CATCH /aws1/cx_rt_generic INTO lo_ex.
        " May already be attached from previous run, check if it's already attached
        TRY.
            DATA(lo_attached) = go_iam->listattachedrolepolicies( iv_rolename = gv_role_name ).
            DATA(lv_already_attached) = abap_false.
            LOOP AT lo_attached->get_attachedpolicies( ) INTO DATA(lo_policy).
              IF lo_policy->get_policyarn( ) = gv_policy_arn.
                lv_already_attached = abap_true.
                EXIT.
              ENDIF.
            ENDLOOP.

            IF lv_already_attached = abap_false.
              cl_abap_unit_assert=>fail( msg = |Failed to attach policy: { lo_ex->get_text( ) }| ).
            ENDIF.
          CATCH /aws1/cx_rt_generic INTO DATA(lo_list_ex).
            cl_abap_unit_assert=>fail( msg = |Failed to verify policy attachment: { lo_list_ex->get_text( ) }| ).
        ENDTRY.
    ENDTRY.

    " Wait for IAM role to propagate (IAM eventual consistency)
    " This is critical for S3 Batch Operations to work
    WAIT UP TO 15 SECONDS.
  ENDMETHOD.

  METHOD class_teardown.
    " Clean up S3 buckets
    IF gv_bucket_name IS NOT INITIAL.
      TRY.
          /awsex/cl_utils=>cleanup_bucket(
            iv_bucket = gv_bucket_name
            io_s3     = go_s3 ).
        CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
          MESSAGE lo_ex->get_text( ) TYPE 'I'.
      ENDTRY.
    ENDIF.

    IF gv_manifest_bucket IS NOT INITIAL.
      TRY.
          /awsex/cl_utils=>cleanup_bucket(
            iv_bucket = gv_manifest_bucket
            io_s3     = go_s3 ).
        CATCH /aws1/cx_rt_generic INTO lo_ex.
          MESSAGE lo_ex->get_text( ) TYPE 'I'.
      ENDTRY.
    ENDIF.

    " Clean up IAM resources
    IF gv_role_name IS NOT INITIAL AND gv_policy_arn IS NOT INITIAL.
      TRY.
          " Detach policy from role
          go_iam->detachrolepolicy(
            iv_rolename  = gv_role_name
            iv_policyarn = gv_policy_arn ).
        CATCH /aws1/cx_rt_generic INTO lo_ex.
          MESSAGE lo_ex->get_text( ) TYPE 'I'.
      ENDTRY.

      TRY.
          " Delete role
          go_iam->deleterole( iv_rolename = gv_role_name ).
        CATCH /aws1/cx_rt_generic INTO lo_ex.
          MESSAGE lo_ex->get_text( ) TYPE 'I'.
      ENDTRY.

      TRY.
          " Delete policy
          go_iam->deletepolicy( iv_policyarn = gv_policy_arn ).
        CATCH /aws1/cx_rt_generic INTO lo_ex.
          MESSAGE lo_ex->get_text( ) TYPE 'I'.
      ENDTRY.
    ENDIF.

    " Cancel any active jobs (don't fail teardown if this fails)
    IF gv_job_id IS NOT INITIAL.
      TRY.
          DATA(lo_job_result) = go_s3c->describejob(
            iv_accountid = gv_account_id
            iv_jobid     = gv_job_id ).

          DATA(lv_status) = lo_job_result->get_job( )->get_status( ).
          IF lv_status = 'Active' OR lv_status = 'Ready' OR lv_status = 'Suspended'.
            go_s3c->updatejobstatus(
              iv_accountid          = gv_account_id
              iv_jobid              = gv_job_id
              iv_requestedjobstatus = 'Cancelled' ).
          ENDIF.
        CATCH /aws1/cx_rt_generic INTO lo_ex.
          MESSAGE lo_ex->get_text( ) TYPE 'I'.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD ensure_job_exists.
    " Helper method to ensure a job exists for tests that need one
    IF gv_job_id IS INITIAL.
      " Get manifest ETag
      TRY.
          DATA(lo_head) = go_s3->headobject(
            iv_bucket = gv_manifest_bucket
            iv_key    = 'job-manifest.csv' ).
          DATA(lv_etag) = lo_head->get_etag( ).
          lv_etag = replace( val = lv_etag sub = '"' with = '' occ = 0 ).
        CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
          cl_abap_unit_assert=>fail( msg = |Failed to get manifest ETag: { lo_ex->get_text( ) }| ).
      ENDTRY.

      " Create job directly using SDK
      TRY.
          DATA(lv_manifest_arn) = |arn:aws:s3:::{ gv_manifest_bucket }/job-manifest.csv|.
          DATA(lo_manifest_location) = NEW /aws1/cl_s3cjobmanifestloc(
            iv_objectarn = lv_manifest_arn
            iv_etag      = lv_etag ).

          DATA lt_fields TYPE /aws1/cl_s3cjobmanifestfield00=>tt_jobmanifestfieldlist.
          APPEND NEW /aws1/cl_s3cjobmanifestfield00( iv_value = 'Bucket' ) TO lt_fields.
          APPEND NEW /aws1/cl_s3cjobmanifestfield00( iv_value = 'Key' ) TO lt_fields.

          DATA(lo_manifest_spec) = NEW /aws1/cl_s3cjobmanifestspec(
            iv_format = 'S3BatchOperations_CSV_20180820'
            it_fields = lt_fields ).

          DATA(lo_manifest) = NEW /aws1/cl_s3cjobmanifest(
            io_spec     = lo_manifest_spec
            io_location = lo_manifest_location ).

          DATA lt_tagset TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.
          APPEND NEW /aws1/cl_s3cs3tag(
            iv_key   = 'BatchTag'
            iv_value = 'BatchValue' ) TO lt_tagset.

          DATA(lo_operation) = NEW /aws1/cl_s3cjoboperation(
            io_s3putobjecttagging = NEW /aws1/cl_s3cs3setobjecttagop( it_tagset = lt_tagset ) ).

          DATA(lo_report) = NEW /aws1/cl_s3cjobreport(
            iv_bucket      = gv_report_bucket_arn
            iv_format      = 'Report_CSV_20180820'
            iv_enabled     = abap_true
            iv_prefix      = 'batch-op-reports'
            iv_reportscope = 'AllTasks' ).

          DATA(lo_result) = go_s3c->createjob(
            iv_accountid             = gv_account_id
            io_operation             = lo_operation
            io_report                = lo_report
            io_manifest              = lo_manifest
            iv_priority              = 10
            iv_rolearn               = gv_role_arn
            iv_description           = 'Batch job for tagging objects'
            iv_confirmationrequired  = abap_true ).

          gv_job_id = lo_result->get_jobid( ).
        CATCH /aws1/cx_rt_generic INTO lo_ex.
          cl_abap_unit_assert=>fail( msg = |Failed to create job: { lo_ex->get_text( ) }| ).
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD create_job.
    " Get manifest ETag
    TRY.
        DATA(lo_head) = go_s3->headobject(
          iv_bucket = gv_manifest_bucket
          iv_key    = 'job-manifest.csv' ).
        DATA(lv_etag) = lo_head->get_etag( ).
        lv_etag = replace( val = lv_etag sub = '"' with = '' occ = 0 ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Failed to get manifest ETag: { lo_ex->get_text( ) }| ).
    ENDTRY.

    " Create job directly using SDK (not via actions class for debugging)
    TRY.
        " Create manifest object
        DATA(lv_manifest_arn) = |arn:aws:s3:::{ gv_manifest_bucket }/job-manifest.csv|.
        DATA(lo_manifest_location) = NEW /aws1/cl_s3cjobmanifestloc(
          iv_objectarn = lv_manifest_arn
          iv_etag      = lv_etag ).

        DATA lt_fields TYPE /aws1/cl_s3cjobmanifestfield00=>tt_jobmanifestfieldlist.
        APPEND NEW /aws1/cl_s3cjobmanifestfield00( iv_value = 'Bucket' ) TO lt_fields.
        APPEND NEW /aws1/cl_s3cjobmanifestfield00( iv_value = 'Key' ) TO lt_fields.

        DATA(lo_manifest_spec) = NEW /aws1/cl_s3cjobmanifestspec(
          iv_format = 'S3BatchOperations_CSV_20180820'
          it_fields = lt_fields ).

        DATA(lo_manifest) = NEW /aws1/cl_s3cjobmanifest(
          io_spec     = lo_manifest_spec
          io_location = lo_manifest_location ).

        " Create operation to tag objects
        DATA lt_tagset TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.
        APPEND NEW /aws1/cl_s3cs3tag(
          iv_key   = 'BatchTag'
          iv_value = 'BatchValue' ) TO lt_tagset.

        DATA(lo_operation) = NEW /aws1/cl_s3cjoboperation(
          io_s3putobjecttagging = NEW /aws1/cl_s3cs3setobjecttagop( it_tagset = lt_tagset ) ).

        " Create report configuration
        DATA(lo_report) = NEW /aws1/cl_s3cjobreport(
          iv_bucket      = gv_report_bucket_arn
          iv_format      = 'Report_CSV_20180820'
          iv_enabled     = abap_true
          iv_prefix      = 'batch-op-reports'
          iv_reportscope = 'AllTasks' ).

        DATA(lo_result) = go_s3c->createjob(
          iv_accountid             = gv_account_id
          io_operation             = lo_operation
          io_report                = lo_report
          io_manifest              = lo_manifest
          iv_priority              = 10
          iv_rolearn               = gv_role_arn
          iv_description           = 'Batch job for tagging objects'
          iv_confirmationrequired  = abap_true ).
      CATCH /aws1/cx_rt_generic INTO lo_ex.
        cl_abap_unit_assert=>fail( msg = |Failed to create job: { lo_ex->get_text( ) }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Job creation result should not be null' ).

    gv_job_id = lo_result->get_jobid( ).

    cl_abap_unit_assert=>assert_not_initial(
      act = gv_job_id
      msg = 'Job ID should not be initial' ).
  ENDMETHOD.

  METHOD update_job_priority.
    " Ensure we have a job created
    ensure_job_exists( ).

    " Wait for job to be in a state where priority can be updated
    DATA(lv_ready) = wait_for_job_status(
      iv_job_id         = gv_job_id
      iv_desired_status = 'Ready'
      iv_max_attempts   = 90 ).

    IF lv_ready = abap_false.
      " Try suspended status as well
      lv_ready = wait_for_job_status(
        iv_job_id         = gv_job_id
        iv_desired_status = 'Suspended'
        iv_max_attempts   = 30 ).
    ENDIF.

    IF lv_ready = abap_false.
      cl_abap_unit_assert=>fail( msg = 'Job did not reach Ready or Suspended status in time' ).
    ENDIF.

    " Update priority directly using SDK
    TRY.
        DATA(lo_result) = go_s3c->updatejobpriority(
          iv_accountid = gv_account_id
          iv_jobid     = gv_job_id
          iv_priority  = 60 ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Failed to update job priority: { lo_ex->get_text( ) }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Priority update result should not be null' ).

    " Verify priority was updated
    TRY.
        DATA(lo_describe) = go_s3c->describejob(
          iv_accountid = gv_account_id
          iv_jobid     = gv_job_id ).

        cl_abap_unit_assert=>assert_equals(
          exp = 60
          act = lo_describe->get_job( )->get_priority( )
          msg = 'Job priority should be updated to 60' ).
      CATCH /aws1/cx_rt_generic INTO lo_ex.
        cl_abap_unit_assert=>fail( msg = |Failed to verify priority update: { lo_ex->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD describe_job.
    " Ensure we have a job created
    ensure_job_exists( ).

    " Describe job directly using SDK
    TRY.
        DATA(lo_result) = go_s3c->describejob(
          iv_accountid = gv_account_id
          iv_jobid     = gv_job_id ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Failed to describe job: { lo_ex->get_text( ) }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Describe job result should not be null' ).

    DATA(lo_job) = lo_result->get_job( ).
    cl_abap_unit_assert=>assert_bound(
      act = lo_job
      msg = 'Job descriptor should not be null' ).

    cl_abap_unit_assert=>assert_equals(
      exp = gv_job_id
      act = lo_job->get_jobid( )
      msg = 'Job ID should match' ).
  ENDMETHOD.

  METHOD get_job_tagging.
    " Ensure we have a job created
    ensure_job_exists( ).

    " Get job tags directly using SDK
    TRY.
        DATA(lo_result) = go_s3c->getjobtagging(
          iv_accountid = gv_account_id
          iv_jobid     = gv_job_id ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Failed to get job tagging: { lo_ex->get_text( ) }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Get job tagging result should not be null' ).

    " Verify we can get tags (even if empty)
    DATA(lt_tags) = lo_result->get_tags( ).
    " Tags list should be bound, can be empty initially
    cl_abap_unit_assert=>assert_bound(
      act = lt_tags
      msg = 'Tags list should be bound' ).
  ENDMETHOD.

  METHOD put_job_tagging.
    " Ensure we have a job created
    ensure_job_exists( ).

    " Create tags to add
    DATA lt_tags TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.
    APPEND NEW /aws1/cl_s3cs3tag(
      iv_key   = 'Environment'
      iv_value = 'Development' ) TO lt_tags.
    APPEND NEW /aws1/cl_s3cs3tag(
      iv_key   = 'Team'
      iv_value = 'DataProcessing' ) TO lt_tags.

    " Put job tags directly using SDK
    TRY.
        DATA(lo_result) = go_s3c->putjobtagging(
          iv_accountid = gv_account_id
          iv_jobid     = gv_job_id
          it_tags      = lt_tags ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Failed to put job tagging: { lo_ex->get_text( ) }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Put job tagging result should not be null' ).

    " Verify tags were added
    TRY.
        DATA(lo_get_tags) = go_s3c->getjobtagging(
          iv_accountid = gv_account_id
          iv_jobid     = gv_job_id ).

        DATA(lt_result_tags) = lo_get_tags->get_tags( ).
        cl_abap_unit_assert=>assert_equals(
          exp = 2
          act = lines( lt_result_tags )
          msg = 'Should have 2 tags' ).
      CATCH /aws1/cx_rt_generic INTO lo_ex.
        cl_abap_unit_assert=>fail( msg = |Failed to verify tags: { lo_ex->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD list_jobs.
    " Ensure we have at least one job created
    ensure_job_exists( ).

    " Create job status list to filter
    DATA lt_job_statuses TYPE /aws1/cl_s3cjobstatuslist_w=>tt_jobstatuslist.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'Active' ) TO lt_job_statuses.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'Complete' ) TO lt_job_statuses.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'Cancelled' ) TO lt_job_statuses.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'Failed' ) TO lt_job_statuses.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'New' ) TO lt_job_statuses.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'Ready' ) TO lt_job_statuses.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'Suspended' ) TO lt_job_statuses.

    " List jobs directly using SDK
    TRY.
        DATA(lo_result) = go_s3c->listjobs(
          iv_accountid   = gv_account_id
          it_jobstatuses = lt_job_statuses ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Failed to list jobs: { lo_ex->get_text( ) }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'List jobs result should not be null' ).

    DATA(lt_jobs) = lo_result->get_jobs( ).
    cl_abap_unit_assert=>assert_bound(
      act = lt_jobs
      msg = 'Jobs list should be bound' ).

    " Verify our job is in the list
    DATA(lv_found) = abap_false.
    LOOP AT lt_jobs INTO DATA(lo_job).
      IF lo_job->get_jobid( ) = gv_job_id.
        lv_found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = 'Created job should be in the list' ).
  ENDMETHOD.

  METHOD delete_job_tagging.
    " Ensure we have a job with tags
    ensure_job_exists( ).

    " Add tags first - this must succeed
    DATA lt_tags TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.
    APPEND NEW /aws1/cl_s3cs3tag(
      iv_key   = 'TestTag'
      iv_value = 'TestValue' ) TO lt_tags.

    TRY.
        go_s3c->putjobtagging(
          iv_accountid = gv_account_id
          iv_jobid     = gv_job_id
          it_tags      = lt_tags ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Failed to add tags before deletion test: { lo_ex->get_text( ) }| ).
    ENDTRY.

    " Delete job tags directly using SDK
    TRY.
        DATA(lo_result) = go_s3c->deletejobtagging(
          iv_accountid = gv_account_id
          iv_jobid     = gv_job_id ).
      CATCH /aws1/cx_rt_generic INTO lo_ex.
        cl_abap_unit_assert=>fail( msg = |Failed to delete job tagging: { lo_ex->get_text( ) }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Delete job tagging result should not be null' ).

    " Verify tags were deleted
    TRY.
        DATA(lo_get_tags) = go_s3c->getjobtagging(
          iv_accountid = gv_account_id
          iv_jobid     = gv_job_id ).

        DATA(lt_result_tags) = lo_get_tags->get_tags( ).
        cl_abap_unit_assert=>assert_equals(
          exp = 0
          act = lines( lt_result_tags )
          msg = 'Should have no tags after deletion' ).
      CATCH /aws1/cx_rt_generic INTO lo_ex.
        cl_abap_unit_assert=>fail( msg = |Failed to verify tag deletion: { lo_ex->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD update_job_status.
    " Ensure we have a job created
    ensure_job_exists( ).

    " Wait for job to be in a state where it can be cancelled
    DATA(lv_ready) = wait_for_job_status(
      iv_job_id         = gv_job_id
      iv_desired_status = 'Ready'
      iv_max_attempts   = 90 ).

    IF lv_ready = abap_false.
      " Try suspended status as well
      lv_ready = wait_for_job_status(
        iv_job_id         = gv_job_id
        iv_desired_status = 'Suspended'
        iv_max_attempts   = 30 ).
    ENDIF.

    IF lv_ready = abap_false.
      cl_abap_unit_assert=>fail( msg = 'Job did not reach Ready or Suspended status in time' ).
    ENDIF.

    " Cancel the job directly using SDK
    TRY.
        DATA(lo_result) = go_s3c->updatejobstatus(
          iv_accountid          = gv_account_id
          iv_jobid              = gv_job_id
          iv_requestedjobstatus = 'Cancelled' ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Failed to update job status: { lo_ex->get_text( ) }| ).
    ENDTRY.

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Update job status result should not be null' ).

    " Wait for cancellation to complete
    DATA lv_max_attempts TYPE i VALUE 60.
    DATA lv_attempt TYPE i VALUE 0.
    DATA lv_cancelled TYPE abap_bool VALUE abap_false.

    WHILE lv_attempt < lv_max_attempts.
      TRY.
          DATA(lo_describe) = go_s3c->describejob(
            iv_accountid = gv_account_id
            iv_jobid     = gv_job_id ).

          DATA(lv_status) = lo_describe->get_job( )->get_status( ).
          IF lv_status = 'Cancelled' OR lv_status = 'Cancelling'.
            lv_cancelled = abap_true.
            EXIT.
          ENDIF.

          WAIT UP TO 2 SECONDS.
          lv_attempt = lv_attempt + 1.
        CATCH /aws1/cx_rt_generic INTO lo_ex.
          " If we get an error after some attempts, the job might be cancelled
          IF lv_attempt > 10.
            lv_cancelled = abap_true.
            EXIT.
          ENDIF.
          WAIT UP TO 2 SECONDS.
          lv_attempt = lv_attempt + 1.
      ENDTRY.
    ENDWHILE.

    IF lv_cancelled = abap_false.
      cl_abap_unit_assert=>fail( msg = 'Job did not reach Cancelled status in time' ).
    ENDIF.
  ENDMETHOD.

  METHOD wait_for_job_status.
    DATA lv_attempt TYPE i VALUE 0.

    rv_success = abap_false.

    WHILE lv_attempt < iv_max_attempts.
      TRY.
          DATA(lo_describe) = go_s3c->describejob(
            iv_accountid = gv_account_id
            iv_jobid     = iv_job_id ).

          DATA(lv_status) = lo_describe->get_job( )->get_status( ).

          IF lv_status = iv_desired_status.
            rv_success = abap_true.
            RETURN.
          ENDIF.

          " Check if job is in a terminal state that can't reach desired status
          IF lv_status = 'Complete' OR lv_status = 'Failed' OR lv_status = 'Cancelled'.
            IF iv_desired_status <> lv_status.
              rv_success = abap_false.
              RETURN.
            ENDIF.
          ENDIF.

          WAIT UP TO 2 SECONDS.
          lv_attempt = lv_attempt + 1.
        CATCH /aws1/cx_rt_generic.
          WAIT UP TO 2 SECONDS.
          lv_attempt = lv_attempt + 1.
      ENDTRY.
    ENDWHILE.
  ENDMETHOD.

ENDCLASS.
