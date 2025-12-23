" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS ltc_awsex_cl_s3c_actions DEFINITION DEFERRED.
CLASS /awsex/cl_s3c_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_s3c_actions.

CLASS ltc_awsex_cl_s3c_actions DEFINITION FOR TESTING DURATION LONG RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA ao_s3c TYPE REF TO /aws1/if_s3c.
    CLASS-DATA ao_s3 TYPE REF TO /aws1/if_s3.
    CLASS-DATA ao_iam TYPE REF TO /aws1/if_iam.
    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_s3c_actions TYPE REF TO /awsex/cl_s3c_actions.
    CLASS-DATA av_account_id TYPE /aws1/s3caccountid.
    CLASS-DATA av_bucket_name TYPE /aws1/s3_bucketname.
    CLASS-DATA av_role_name TYPE /aws1/iamrolenametype.
    CLASS-DATA av_role_arn TYPE /aws1/s3ciamrolearn.
    CLASS-DATA av_policy_arn TYPE /aws1/iamarntype.
    CLASS-DATA av_job_id TYPE /aws1/s3cjobid.
    CLASS-DATA av_job_id_for_update_prio TYPE /aws1/s3cjobid.
    CLASS-DATA av_job_id_for_cancel TYPE /aws1/s3cjobid.
    CLASS-DATA av_manifest_etag TYPE /aws1/s3cnonemptymaxlength1000.
    CLASS-DATA av_setup_failed TYPE abap_bool.

    METHODS: create_job FOR TESTING RAISING /aws1/cx_rt_generic,
      update_job_priority FOR TESTING RAISING /aws1/cx_rt_generic,
      update_job_status FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_job FOR TESTING RAISING /aws1/cx_rt_generic,
      get_job_tagging FOR TESTING RAISING /aws1/cx_rt_generic,
      put_job_tagging FOR TESTING RAISING /aws1/cx_rt_generic,
      list_jobs FOR TESTING RAISING /aws1/cx_rt_generic,
      delete_job_tagging FOR TESTING RAISING /aws1/cx_rt_generic.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic.

    METHODS wait_for_job_status
      IMPORTING
        iv_job_id        TYPE /aws1/s3cjobid
        iv_target_status TYPE /aws1/s3cjobstatus
      RAISING
        /aws1/cx_rt_generic.

    METHODS create_batch_job_helper
      IMPORTING
        iv_suffix              TYPE string DEFAULT ''
      RETURNING
        VALUE(rv_job_id)       TYPE /aws1/s3cjobid
      RAISING
        /aws1/cx_rt_generic.
ENDCLASS.

CLASS ltc_awsex_cl_s3c_actions IMPLEMENTATION.

  METHOD class_setup.
    av_setup_failed = abap_false.
    
    TRY.
        ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
        ao_s3c = /aws1/cl_s3c_factory=>create( ao_session ).
        ao_s3 = /aws1/cl_s3_factory=>create( ao_session ).
        ao_iam = /aws1/cl_iam_factory=>create( ao_session ).
        ao_s3c_actions = NEW /awsex/cl_s3c_actions( ).

        av_account_id = ao_session->get_account_id( ).
        DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
        DATA(lv_uuid_string) TYPE string.
        lv_uuid_string = lv_uuid.
        av_bucket_name = |s3c-batch-{ lv_uuid_string }|.
        av_role_name = |S3BatchRole{ lv_uuid_string }|.

        " Create S3 bucket using utils
        /awsex/cl_utils=>create_bucket(
          iv_bucket = av_bucket_name
          io_s3 = ao_s3
          io_session = ao_session
        ).

        " Tag the bucket for cleanup
        ao_s3->putbuckettagging(
          iv_bucket = av_bucket_name
          io_tagging = NEW /aws1/cl_s3_tagging(
            it_tagset = VALUE /aws1/cl_s3_tag=>tt_tagset(
              ( NEW /aws1/cl_s3_tag( iv_key = 'convert_test' iv_value = 'true' ) )
            )
          )
        ).

        " Wait for bucket to be ready
        DATA(lv_wait_count) = 0.
        WHILE lv_wait_count < 30.
          TRY.
              ao_s3->headbucket( iv_bucket = av_bucket_name ).
              EXIT.
            CATCH /aws1/cx_s3_nosuchbucket.
              WAIT UP TO 2 SECONDS.
              lv_wait_count = lv_wait_count + 1.
          ENDTRY.
        ENDWHILE.

        IF lv_wait_count >= 30.
          av_setup_failed = abap_true.
          cl_abap_unit_assert=>fail( msg = |Bucket { av_bucket_name } was not ready after 60 seconds| ).
          RETURN.
        ENDIF.

    " Create IAM role for S3 Batch Operations
    DATA(lv_assume_role_policy) = |{
      "Version": "2012-10-17",
      "Statement": [\{
        "Effect": "Allow",
        "Principal": \{
          "Service": "batchoperations.s3.amazonaws.com"
        \},
        "Action": "sts:AssumeRole"
      \}]
    \}|.

    TRY.
        DATA(lo_create_role_result) = ao_iam->createrole(
          iv_rolename = av_role_name
          iv_assumerolepolicydocument = lv_assume_role_policy
          it_tags = VALUE /aws1/cl_iamtag=>tt_taglisttype(
            ( NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) )
          )
        ).
        av_role_arn = lo_create_role_result->get_role( )->get_arn( ).
      CATCH /aws1/cx_iamentityalrdyexists.
        " Role already exists
        DATA(lo_get_role_result) = ao_iam->getrole( iv_rolename = av_role_name ).
        av_role_arn = lo_get_role_result->get_role( )->get_arn( ).
    ENDTRY.

    " Create and attach IAM policy
    DATA(lv_policy_document) = |{
      "Version": "2012-10-17",
      "Statement": [\{
        "Effect": "Allow",
        "Action": [
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectTagging",
          "s3:GetObjectVersionTagging",
          "s3:PutObjectVersionTagging",
          "s3:PutObjectAcl",
          "s3:PutObjectVersionAcl",
          "s3:DeleteObjectTagging",
          "s3:DeleteObjectVersionTagging"
        ],
        "Resource": "arn:aws:s3:::{ av_bucket_name }/*"
      \},\{
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ],
        "Resource": "arn:aws:s3:::{ av_bucket_name }/*"
      \},\{
        "Effect": "Allow",
        "Action": [
          "s3:GetBucketLocation"
        ],
        "Resource": "arn:aws:s3:::{ av_bucket_name }"
      \}]
    \}|.

    DATA(lv_policy_name) = |S3BatchPolicy{ lv_uuid_string }|.
    TRY.
        DATA(lo_policy_result) = ao_iam->createpolicy(
          iv_policyname = lv_policy_name
          iv_policydocument = lv_policy_document
          it_tags = VALUE /aws1/cl_iamtag=>tt_taglisttype(
            ( NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) )
          )
        ).
        av_policy_arn = lo_policy_result->get_policy( )->get_arn( ).
      CATCH /aws1/cx_iamentityalrdyexists.
        " Policy already exists - construct ARN
        av_policy_arn = |arn:aws:iam::{ av_account_id }:policy/{ lv_policy_name }|.
    ENDTRY.

    " Attach policy to role
    TRY.
        ao_iam->attachrolepolicy(
          iv_rolename = av_role_name
          iv_policyarn = av_policy_arn
        ).
      CATCH /aws1/cx_rt_generic.
        " Policy might already be attached
    ENDTRY.

    " Wait for IAM role to propagate
    WAIT UP TO 10 SECONDS.

    " Create manifest file and upload to S3
    DATA(lv_manifest_content) = |{ av_bucket_name },object-key-1.txt\n|
                              && |{ av_bucket_name },object-key-2.txt\n|
                              && |{ av_bucket_name },object-key-3.txt|.

    " Upload sample objects
    DATA(lt_objects) = VALUE /aws1/if_s3=>tt_objectkey(
      ( |object-key-1.txt| )
      ( |object-key-2.txt| )
      ( |object-key-3.txt| )
    ).

    LOOP AT lt_objects INTO DATA(lv_object_key).
      TRY.
          ao_s3->putobject(
            iv_bucket = av_bucket_name
            iv_key = lv_object_key
            iv_body = |Content for { lv_object_key }|
            it_tagging = VALUE /aws1/cl_s3_tag=>tt_tagging(
              ( NEW /aws1/cl_s3_tag( iv_key = 'convert_test' iv_value = 'true' ) )
            )
          ).
        CATCH /aws1/cx_rt_generic.
          " Continue even if object upload fails
      ENDTRY.
    ENDLOOP.

    " Upload manifest file
    DATA(lo_manifest_result) = ao_s3->putobject(
      iv_bucket = av_bucket_name
      iv_key = 'job-manifest.csv'
      iv_body = lv_manifest_content
      it_tagging = VALUE /aws1/cl_s3_tag=>tt_tagging(
        ( NEW /aws1/cl_s3_tag( iv_key = 'convert_test' iv_value = 'true' ) )
      )
    ).

    av_manifest_etag = lo_manifest_result->get_etag( ).
    IF av_manifest_etag IS NOT INITIAL.
      REPLACE ALL OCCURRENCES OF '"' IN av_manifest_etag WITH ''.
    ENDIF.
  ENDMETHOD.

  METHOD class_teardown.
    " Cancel job if it exists and is not complete
    IF av_job_id IS NOT INITIAL.
      TRY.
          DATA(lo_describe_result) = ao_s3c->describejob(
            iv_accountid = av_account_id
            iv_jobid = av_job_id
          ).
          DATA(lv_status) = lo_describe_result->get_job( )->get_status( ).
          IF lv_status = 'Ready' OR lv_status = 'Suspended' OR lv_status = 'Active'.
            TRY.
                ao_s3c->updatejobstatus(
                  iv_accountid = av_account_id
                  iv_jobid = av_job_id
                  iv_requestedjobstatus = 'Cancelled'
                ).
              CATCH /aws1/cx_rt_generic.
                " Job might not be cancellable
            ENDTRY.
          ENDIF.
        CATCH /aws1/cx_rt_generic.
          " Job might not exist
      ENDTRY.
    ENDIF.

    " Clean up S3 bucket - do NOT delete bucket since job reports may still be writing
    IF av_bucket_name IS NOT INITIAL.
      TRY.
          " Tag bucket for manual cleanup instead of deleting
          ao_s3->putbuckettagging(
            iv_bucket = av_bucket_name
            io_tagging = NEW /aws1/cl_s3_tagging(
              it_tagset = VALUE /aws1/cl_s3_tag=>tt_tagset(
                ( NEW /aws1/cl_s3_tag( iv_key = 'convert_test' iv_value = 'true' ) )
                ( NEW /aws1/cl_s3_tag( iv_key = 'cleanup_needed' iv_value = 'true' ) )
              )
            )
          ).
        CATCH /aws1/cx_rt_generic.
          " Continue cleanup
      ENDTRY.
    ENDIF.

    " Detach policy from role
    IF av_role_name IS NOT INITIAL AND av_policy_arn IS NOT INITIAL.
      TRY.
          ao_iam->detachrolepolicy(
            iv_rolename = av_role_name
            iv_policyarn = av_policy_arn
          ).
        CATCH /aws1/cx_rt_generic.
          " Policy might already be detached
      ENDTRY.
    ENDIF.

    " Delete IAM policy
    IF av_policy_arn IS NOT INITIAL.
      TRY.
          ao_iam->deletepolicy( iv_policyarn = av_policy_arn ).
        CATCH /aws1/cx_rt_generic.
          " Policy might not exist
      ENDTRY.
    ENDIF.

    " Delete IAM role
    IF av_role_name IS NOT INITIAL.
      TRY.
          ao_iam->deleterole( iv_rolename = av_role_name ).
        CATCH /aws1/cx_rt_generic.
          " Role might not exist
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD create_job.
    DATA(lv_manifest_location) = |arn:aws:s3:::{ av_bucket_name }/job-manifest.csv|.
    DATA(lv_report_bucket) = |arn:aws:s3:::{ av_bucket_name }|.

    av_job_id = ao_s3c_actions->create_job(
      iv_account_id = av_account_id
      iv_role_arn = av_role_arn
      iv_manifest_location = lv_manifest_location
      iv_manifest_etag = av_manifest_etag
      iv_report_bucket = lv_report_bucket
    ).

    cl_abap_unit_assert=>assert_not_initial(
      act = av_job_id
      msg = |Job ID should not be empty| ).

    " Wait for job to be ready
    wait_for_job_status(
      iv_job_id = av_job_id
      iv_target_status = 'Ready'
    ).
  ENDMETHOD.

  METHOD update_job_priority.
    IF av_job_id IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Job ID not set. Run create_job test first.' ).
    ENDIF.

    ao_s3c_actions->update_job_priority(
      iv_account_id = av_account_id
      iv_job_id = av_job_id
      iv_priority = 60
    ).

    " Verify priority was updated
    DATA(lo_describe_result) = ao_s3c->describejob(
      iv_accountid = av_account_id
      iv_jobid = av_job_id
    ).

    DATA(lv_priority) = lo_describe_result->get_job( )->get_priority( ).
    cl_abap_unit_assert=>assert_equals(
      exp = 60
      act = lv_priority
      msg = |Job priority should be 60| ).
  ENDMETHOD.

  METHOD update_job_status.
    IF av_job_id IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Job ID not set. Run create_job test first.' ).
    ENDIF.

    " Check current status first
    DATA(lo_describe_result) = ao_s3c->describejob(
      iv_accountid = av_account_id
      iv_jobid = av_job_id
    ).

    DATA(lv_current_status) = lo_describe_result->get_job( )->get_status( ).

    " Only cancel if job is in a cancellable state
    IF lv_current_status = 'Ready' OR lv_current_status = 'Suspended' OR lv_current_status = 'Active'.
      ao_s3c_actions->update_job_status(
        iv_account_id = av_account_id
        iv_job_id = av_job_id
        iv_requested_job_status = 'Cancelled'
        iv_status_update_reason = 'Testing job cancellation'
      ).

      " Wait for status to update
      WAIT UP TO 5 SECONDS.

      " Verify status was updated
      lo_describe_result = ao_s3c->describejob(
        iv_accountid = av_account_id
        iv_jobid = av_job_id
      ).

      DATA(lv_updated_status) = lo_describe_result->get_job( )->get_status( ).
      cl_abap_unit_assert=>assert_true(
        act = xsdbool( lv_updated_status = 'Cancelled' OR lv_updated_status = 'Cancelling' )
        msg = |Job status should be Cancelled or Cancelling| ).
    ENDIF.
  ENDMETHOD.

  METHOD describe_job.
    IF av_job_id IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Job ID not set. Run create_job test first.' ).
    ENDIF.

    DATA lo_result TYPE REF TO /aws1/cl_s3cdescribejobresult.
    ao_s3c_actions->describe_job(
      EXPORTING
        iv_account_id = av_account_id
        iv_job_id = av_job_id
      IMPORTING
        oo_result = lo_result
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Result should not be null| ).

    DATA(lo_job) = lo_result->get_job( ).
    cl_abap_unit_assert=>assert_bound(
      act = lo_job
      msg = |Job descriptor should not be null| ).

    DATA(lv_job_id) = lo_job->get_jobid( ).
    cl_abap_unit_assert=>assert_equals(
      exp = av_job_id
      act = lv_job_id
      msg = |Job ID should match| ).
  ENDMETHOD.

  METHOD get_job_tagging.
    IF av_job_id IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Job ID not set. Run create_job test first.' ).
    ENDIF.

    DATA lo_result TYPE REF TO /aws1/cl_s3cgetjobtagresult.
    ao_s3c_actions->get_job_tagging(
      EXPORTING
        iv_account_id = av_account_id
        iv_job_id = av_job_id
      IMPORTING
        oo_result = lo_result
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Result should not be null| ).
  ENDMETHOD.

  METHOD put_job_tagging.
    IF av_job_id IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Job ID not set. Run create_job test first.' ).
    ENDIF.

    DATA(lt_tags) = VALUE /aws1/cl_s3cs3tag=>tt_s3tagset(
      ( NEW /aws1/cl_s3cs3tag( iv_key = 'Environment' iv_value = 'Development' ) )
      ( NEW /aws1/cl_s3cs3tag( iv_key = 'Team' iv_value = 'DataProcessing' ) )
    ).

    ao_s3c_actions->put_job_tagging(
      iv_account_id = av_account_id
      iv_job_id = av_job_id
      it_tags = lt_tags
    ).

    " Verify tags were added
    DATA(lo_result) = ao_s3c->getjobtagging(
      iv_accountid = av_account_id
      iv_jobid = av_job_id
    ).

    DATA(lt_retrieved_tags) = lo_result->get_tags( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_retrieved_tags
      msg = |Tags should not be empty| ).
  ENDMETHOD.

  METHOD list_jobs.
    DATA lo_result TYPE REF TO /aws1/cl_s3clistjobsresult.
    ao_s3c_actions->list_jobs(
      EXPORTING
        iv_account_id = av_account_id
        it_job_statuses = VALUE /aws1/cl_s3cjobstatuslist_w=>tt_jobstatuslist(
          ( NEW /aws1/cl_s3cjobstatuslist_w( 'Active' ) )
          ( NEW /aws1/cl_s3cjobstatuslist_w( 'Complete' ) )
          ( NEW /aws1/cl_s3cjobstatuslist_w( 'Cancelled' ) )
          ( NEW /aws1/cl_s3cjobstatuslist_w( 'Failed' ) )
          ( NEW /aws1/cl_s3cjobstatuslist_w( 'New' ) )
          ( NEW /aws1/cl_s3cjobstatuslist_w( 'Ready' ) )
          ( NEW /aws1/cl_s3cjobstatuslist_w( 'Suspended' ) )
        )
      IMPORTING
        oo_result = lo_result
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Result should not be null| ).

    DATA(lt_jobs) = lo_result->get_jobs( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_jobs
      msg = |Jobs list should not be empty| ).
  ENDMETHOD.

  METHOD delete_job_tagging.
    IF av_job_id IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Job ID not set. Run create_job test first.' ).
    ENDIF.

    ao_s3c_actions->delete_job_tagging(
      iv_account_id = av_account_id
      iv_job_id = av_job_id
    ).

    " Verify tags were deleted
    DATA(lo_result) = ao_s3c->getjobtagging(
      iv_accountid = av_account_id
      iv_jobid = av_job_id
    ).

    DATA(lt_tags) = lo_result->get_tags( ).
    cl_abap_unit_assert=>assert_initial(
      act = lt_tags
      msg = |Tags should be empty after deletion| ).
  ENDMETHOD.

  METHOD wait_for_job_status.
    DATA(lv_wait_count) = 0.
    DATA(lv_max_waits) = 60.

    WHILE lv_wait_count < lv_max_waits.
      DATA(lo_describe_result) = ao_s3c->describejob(
        iv_accountid = av_account_id
        iv_jobid = iv_job_id
      ).

      DATA(lv_current_status) = lo_describe_result->get_job( )->get_status( ).

      IF lv_current_status = iv_target_status.
        EXIT.
      ELSEIF lv_current_status = 'Suspended' AND iv_target_status = 'Ready'.
        " Suspended is also acceptable for Ready
        EXIT.
      ELSEIF lv_current_status = 'Active' OR lv_current_status = 'Failed'
          OR lv_current_status = 'Cancelled' OR lv_current_status = 'Complete'.
        " Job is in a terminal or active state
        EXIT.
      ENDIF.

      WAIT UP TO 5 SECONDS.
      lv_wait_count = lv_wait_count + 1.
    ENDWHILE.
  ENDMETHOD.
ENDCLASS.
