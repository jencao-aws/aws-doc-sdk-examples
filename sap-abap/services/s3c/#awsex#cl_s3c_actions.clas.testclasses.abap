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
    DATA lv_uuid_string TYPE string.
    DATA lv_wait_count TYPE i.
    DATA lv_assume_role_policy TYPE /aws1/iampolicydocumenttype.
    DATA lo_create_role_result TYPE REF TO /aws1/cl_iamcreateroleresponse.
    DATA lv_policy_document TYPE /aws1/iampolicydocumenttype.
    DATA lv_policy_name TYPE /aws1/iampolicynametype.
    DATA lo_policy_result TYPE REF TO /aws1/cl_iamcreatepolicyrsp.
    DATA lt_objects TYPE STANDARD TABLE OF /aws1/s3_objectkey.
    DATA lv_object_key TYPE /aws1/s3_objectkey.
    DATA lv_manifest_content TYPE string.
    DATA lo_manifest_result TYPE REF TO /aws1/cl_s3_putobjectoutput.
    DATA lo_generic_ex TYPE REF TO /aws1/cx_rt_generic.

    av_setup_failed = abap_false.
    
    TRY.
        ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
        ao_s3c = /aws1/cl_s3c_factory=>create( ao_session ).
        ao_s3 = /aws1/cl_s3_factory=>create( ao_session ).
        ao_iam = /aws1/cl_iam_factory=>create( ao_session ).
        ao_s3c_actions = NEW /awsex/cl_s3c_actions( ).

        av_account_id = ao_session->get_account_id( ).
        lv_uuid_string = /awsex/cl_utils=>get_random_string( ).
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
        lv_wait_count = 0.
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
        lv_assume_role_policy = |\{ | &&
          |"Version": "2012-10-17", | &&
          |"Statement": [\{ | &&
          |"Effect": "Allow", | &&
          |"Principal": \{ | &&
          |"Service": "batchoperations.s3.amazonaws.com" | &&
          |\}, | &&
          |"Action": "sts:AssumeRole" | &&
          |\}] | &&
          |\}|.

        lo_create_role_result = ao_iam->createrole(
          iv_rolename = av_role_name
          iv_assumerolepolicydocument = lv_assume_role_policy
          it_tags = VALUE /aws1/cl_iamtag=>tt_taglisttype(
            ( NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) )
          )
        ).
        av_role_arn = lo_create_role_result->get_role( )->get_arn( ).

        " Create and attach IAM policy with all necessary permissions
        lv_policy_document = |\{ | &&
          |"Version": "2012-10-17", | &&
          |"Statement": [\{ | &&
          |"Effect": "Allow", | &&
          |"Action": [ | &&
          |"s3:PutObject", | &&
          |"s3:PutObjectTagging", | &&
          |"s3:GetObject", | &&
          |"s3:GetObjectVersion", | &&
          |"s3:GetObjectTagging", | &&
          |"s3:GetObjectVersionTagging", | &&
          |"s3:PutObjectVersionTagging", | &&
          |"s3:PutObjectAcl", | &&
          |"s3:PutObjectVersionAcl", | &&
          |"s3:DeleteObjectTagging", | &&
          |"s3:DeleteObjectVersionTagging", | &&
          |"s3:ListBucket" | &&
          |], | &&
          |"Resource": [ | &&
          |"arn:aws:s3:::{ av_bucket_name }/*", | &&
          |"arn:aws:s3:::{ av_bucket_name }" | &&
          |] | &&
          |\}] | &&
          |\}|.

        lv_policy_name = |S3BatchPol{ lv_uuid_string }|.
        lo_policy_result = ao_iam->createpolicy(
          iv_policyname = lv_policy_name
          iv_policydocument = lv_policy_document
          it_tags = VALUE /aws1/cl_iamtag=>tt_taglisttype(
            ( NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) )
          )
        ).
        av_policy_arn = lo_policy_result->get_policy( )->get_arn( ).

        " Attach policy to role
        ao_iam->attachrolepolicy(
          iv_rolename = av_role_name
          iv_policyarn = av_policy_arn
        ).

        " Wait for IAM role to propagate
        WAIT UP TO 10 SECONDS.

        " Upload sample objects to S3
        APPEND |object-key-1.txt| TO lt_objects.
        APPEND |object-key-2.txt| TO lt_objects.
        APPEND |object-key-3.txt| TO lt_objects.

        LOOP AT lt_objects INTO lv_object_key.
          ao_s3->putobject(
            iv_bucket = av_bucket_name
            iv_key = lv_object_key
            iv_body = |Content for { lv_object_key }|
            it_tagging = VALUE /aws1/cl_s3_tag=>tt_tagging(
              ( NEW /aws1/cl_s3_tag( iv_key = 'convert_test' iv_value = 'true' ) )
            )
          ).
        ENDLOOP.

        " Create and upload manifest file
        lv_manifest_content = |{ av_bucket_name },object-key-1.txt\n| &&
                              |{ av_bucket_name },object-key-2.txt\n| &&
                              |{ av_bucket_name },object-key-3.txt|.

        lo_manifest_result = ao_s3->putobject(
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

      CATCH /aws1/cx_rt_generic INTO lo_generic_ex.
        av_setup_failed = abap_true.
        cl_abap_unit_assert=>fail( msg = |Setup failed: { lo_generic_ex->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD class_teardown.
    DATA lo_describe_result TYPE REF TO /aws1/cl_s3cdescribejobresult.
    DATA lv_status TYPE /aws1/s3cjobstatus.

    " Clean up S3 bucket - do NOT delete bucket since job reports may still be writing
    " Tag bucket for manual cleanup instead
    IF av_bucket_name IS NOT INITIAL.
      TRY.
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
    DATA lv_manifest_location TYPE /aws1/s3cs3keyarnstring.
    DATA lv_report_bucket TYPE /aws1/s3cs3bucketarnstring.
    DATA lv_job_id TYPE /aws1/s3cjobid.

    " Fail if setup failed
    IF av_setup_failed = abap_true.
      cl_abap_unit_assert=>fail( msg = 'Setup failed. Cannot run test.' ).
    ENDIF.

    lv_manifest_location = |arn:aws:s3:::{ av_bucket_name }/job-manifest.csv|.
    lv_report_bucket = |arn:aws:s3:::{ av_bucket_name }|.

    lv_job_id = ao_s3c_actions->create_job(
      iv_account_id = av_account_id
      iv_role_arn = av_role_arn
      iv_manifest_location = lv_manifest_location
      iv_manifest_etag = av_manifest_etag
      iv_report_bucket = lv_report_bucket
    ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_job_id
      msg = |Job ID should not be empty| ).

    " Wait for job to be ready or suspended
    wait_for_job_status(
      iv_job_id = lv_job_id
      iv_target_status = 'Ready'
    ).

    " Clean up - cancel the job
    TRY.
        ao_s3c->updatejobstatus(
          iv_accountid = av_account_id
          iv_jobid = lv_job_id
          iv_requestedjobstatus = 'Cancelled'
        ).
      CATCH /aws1/cx_rt_generic.
        " Job might not be cancellable
    ENDTRY.
  ENDMETHOD.

  METHOD update_job_priority.
    DATA lv_job_id TYPE /aws1/s3cjobid.
    DATA lo_describe_result TYPE REF TO /aws1/cl_s3cdescribejobresult.
    DATA lv_priority TYPE /aws1/s3cjobpriority.

    " Fail if setup failed
    IF av_setup_failed = abap_true.
      cl_abap_unit_assert=>fail( msg = 'Setup failed. Cannot run test.' ).
    ENDIF.

    " Create a new job for this test
    lv_job_id = create_batch_job_helper( '_priority' ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_job_id
      msg = |Job ID should not be empty| ).

    " Wait for job to be ready
    wait_for_job_status(
      iv_job_id = lv_job_id
      iv_target_status = 'Ready'
    ).

    " Update priority
    ao_s3c_actions->update_job_priority(
      iv_account_id = av_account_id
      iv_job_id = lv_job_id
      iv_priority = 60
    ).

    " Verify priority was updated
    lo_describe_result = ao_s3c->describejob(
      iv_accountid = av_account_id
      iv_jobid = lv_job_id
    ).

    lv_priority = lo_describe_result->get_job( )->get_priority( ).
    cl_abap_unit_assert=>assert_equals(
      exp = 60
      act = lv_priority
      msg = |Job priority should be 60| ).

    " Clean up - cancel the job
    TRY.
        ao_s3c->updatejobstatus(
          iv_accountid = av_account_id
          iv_jobid = lv_job_id
          iv_requestedjobstatus = 'Cancelled'
        ).
      CATCH /aws1/cx_rt_generic.
        " Job might not be cancellable
    ENDTRY.
  ENDMETHOD.

  METHOD update_job_status.
    DATA lv_job_id TYPE /aws1/s3cjobid.
    DATA lo_describe_result TYPE REF TO /aws1/cl_s3cdescribejobresult.
    DATA lv_current_status TYPE /aws1/s3cjobstatus.
    DATA lv_updated_status TYPE /aws1/s3cjobstatus.

    " Fail if setup failed
    IF av_setup_failed = abap_true.
      cl_abap_unit_assert=>fail( msg = 'Setup failed. Cannot run test.' ).
    ENDIF.

    " Create a new job for this test
    lv_job_id = create_batch_job_helper( '_cancel' ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_job_id
      msg = |Job ID should not be empty| ).

    " Wait for job to be ready
    wait_for_job_status(
      iv_job_id = lv_job_id
      iv_target_status = 'Ready'
    ).

    " Check current status before cancelling
    lo_describe_result = ao_s3c->describejob(
      iv_accountid = av_account_id
      iv_jobid = lv_job_id
    ).

    lv_current_status = lo_describe_result->get_job( )->get_status( ).

    " Cancel job
    IF lv_current_status = 'Ready' OR lv_current_status = 'Suspended' OR lv_current_status = 'Active'.
      ao_s3c_actions->update_job_status(
        iv_account_id = av_account_id
        iv_job_id = lv_job_id
        iv_requested_job_status = 'Cancelled'
        iv_status_update_reason = 'Testing job cancellation'
      ).

      " Wait for status to update
      WAIT UP TO 5 SECONDS.

      " Verify status was updated
      lo_describe_result = ao_s3c->describejob(
        iv_accountid = av_account_id
        iv_jobid = lv_job_id
      ).

      lv_updated_status = lo_describe_result->get_job( )->get_status( ).
      cl_abap_unit_assert=>assert_true(
        act = xsdbool( lv_updated_status = 'Cancelled' OR lv_updated_status = 'Cancelling' )
        msg = |Job status should be Cancelled or Cancelling, but was { lv_updated_status }| ).
    ELSE.
      cl_abap_unit_assert=>fail( msg = |Job status is { lv_current_status }, cannot cancel| ).
    ENDIF.
  ENDMETHOD.

  METHOD describe_job.
    DATA lv_job_id TYPE /aws1/s3cjobid.
    DATA lo_result TYPE REF TO /aws1/cl_s3cdescribejobresult.
    DATA lo_job TYPE REF TO /aws1/cl_s3cjobdescriptor.
    DATA lv_returned_job_id TYPE /aws1/s3cjobid.

    " Fail if setup failed
    IF av_setup_failed = abap_true.
      cl_abap_unit_assert=>fail( msg = 'Setup failed. Cannot run test.' ).
    ENDIF.

    " Create a new job for this test
    lv_job_id = create_batch_job_helper( '_describe' ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_job_id
      msg = |Job ID should not be empty| ).

    " Describe the job
    ao_s3c_actions->describe_job(
      EXPORTING
        iv_account_id = av_account_id
        iv_job_id = lv_job_id
      IMPORTING
        oo_result = lo_result
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Result should not be null| ).

    lo_job = lo_result->get_job( ).
    cl_abap_unit_assert=>assert_bound(
      act = lo_job
      msg = |Job descriptor should not be null| ).

    lv_returned_job_id = lo_job->get_jobid( ).
    cl_abap_unit_assert=>assert_equals(
      exp = lv_job_id
      act = lv_returned_job_id
      msg = |Job ID should match| ).

    " Clean up - cancel the job
    TRY.
        ao_s3c->updatejobstatus(
          iv_accountid = av_account_id
          iv_jobid = lv_job_id
          iv_requestedjobstatus = 'Cancelled'
        ).
      CATCH /aws1/cx_rt_generic.
        " Job might not be cancellable
    ENDTRY.
  ENDMETHOD.

  METHOD get_job_tagging.
    DATA lv_job_id TYPE /aws1/s3cjobid.
    DATA lo_result TYPE REF TO /aws1/cl_s3cgetjobtagresult.

    " Fail if setup failed
    IF av_setup_failed = abap_true.
      cl_abap_unit_assert=>fail( msg = 'Setup failed. Cannot run test.' ).
    ENDIF.

    " Create a new job for this test
    lv_job_id = create_batch_job_helper( '_gettag' ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_job_id
      msg = |Job ID should not be empty| ).

    " Get job tags
    ao_s3c_actions->get_job_tagging(
      EXPORTING
        iv_account_id = av_account_id
        iv_job_id = lv_job_id
      IMPORTING
        oo_result = lo_result
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Result should not be null| ).

    " Clean up - cancel the job
    TRY.
        ao_s3c->updatejobstatus(
          iv_accountid = av_account_id
          iv_jobid = lv_job_id
          iv_requestedjobstatus = 'Cancelled'
        ).
      CATCH /aws1/cx_rt_generic.
        " Job might not be cancellable
    ENDTRY.
  ENDMETHOD.

  METHOD put_job_tagging.
    DATA lv_job_id TYPE /aws1/s3cjobid.
    DATA lt_tags TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.
    DATA lo_result TYPE REF TO /aws1/cl_s3cgetjobtagresult.
    DATA lt_retrieved_tags TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.
    DATA lo_tag TYPE REF TO /aws1/cl_s3cs3tag.
    DATA lv_key TYPE /aws1/s3ctagkeystring.
    DATA lv_value TYPE /aws1/s3ctagvaluestring.
    DATA lv_found_env TYPE abap_bool.
    DATA lv_found_team TYPE abap_bool.

    " Fail if setup failed
    IF av_setup_failed = abap_true.
      cl_abap_unit_assert=>fail( msg = 'Setup failed. Cannot run test.' ).
    ENDIF.

    " Create a new job for this test
    lv_job_id = create_batch_job_helper( '_puttag' ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_job_id
      msg = |Job ID should not be empty| ).

    " Add tags to job
    lt_tags = VALUE /aws1/cl_s3cs3tag=>tt_s3tagset(
      ( NEW /aws1/cl_s3cs3tag( iv_key = 'Environment' iv_value = 'Development' ) )
      ( NEW /aws1/cl_s3cs3tag( iv_key = 'Team' iv_value = 'DataProcessing' ) )
    ).

    ao_s3c_actions->put_job_tagging(
      iv_account_id = av_account_id
      iv_job_id = lv_job_id
      it_tags = lt_tags
    ).

    " Verify tags were added
    lo_result = ao_s3c->getjobtagging(
      iv_accountid = av_account_id
      iv_jobid = lv_job_id
    ).

    lt_retrieved_tags = lo_result->get_tags( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_retrieved_tags
      msg = |Tags should not be empty| ).

    " Verify we have at least the tags we added
    lv_found_env = abap_false.
    lv_found_team = abap_false.
    LOOP AT lt_retrieved_tags INTO lo_tag.
      lv_key = lo_tag->get_key( ).
      lv_value = lo_tag->get_value( ).
      IF lv_key = 'Environment' AND lv_value = 'Development'.
        lv_found_env = abap_true.
      ELSEIF lv_key = 'Team' AND lv_value = 'DataProcessing'.
        lv_found_team = abap_true.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found_env
      msg = |Environment tag should be found| ).

    cl_abap_unit_assert=>assert_true(
      act = lv_found_team
      msg = |Team tag should be found| ).

    " Clean up - cancel the job
    TRY.
        ao_s3c->updatejobstatus(
          iv_accountid = av_account_id
          iv_jobid = lv_job_id
          iv_requestedjobstatus = 'Cancelled'
        ).
      CATCH /aws1/cx_rt_generic.
        " Job might not be cancellable
    ENDTRY.
  ENDMETHOD.

  METHOD list_jobs.
    DATA lv_job_id TYPE /aws1/s3cjobid.
    DATA lo_result TYPE REF TO /aws1/cl_s3clistjobsresult.
    DATA lt_jobs TYPE /aws1/cl_s3cjoblistdescriptor=>tt_joblistdescriptorlist.
    DATA lv_found TYPE abap_bool.
    DATA lo_job TYPE REF TO /aws1/cl_s3cjoblistdescriptor.

    " Fail if setup failed
    IF av_setup_failed = abap_true.
      cl_abap_unit_assert=>fail( msg = 'Setup failed. Cannot run test.' ).
    ENDIF.

    " Create a new job to ensure we have at least one job
    lv_job_id = create_batch_job_helper( '_list' ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_job_id
      msg = |Job ID should not be empty| ).

    " List jobs
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

    lt_jobs = lo_result->get_jobs( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_jobs
      msg = |Jobs list should not be empty| ).

    " Verify our job is in the list
    lv_found = abap_false.
    LOOP AT lt_jobs INTO lo_job.
      IF lo_job->get_jobid( ) = lv_job_id.
        lv_found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = |Created job should be in the list| ).

    " Clean up - cancel the job
    TRY.
        ao_s3c->updatejobstatus(
          iv_accountid = av_account_id
          iv_jobid = lv_job_id
          iv_requestedjobstatus = 'Cancelled'
        ).
      CATCH /aws1/cx_rt_generic.
        " Job might not be cancellable
    ENDTRY.
  ENDMETHOD.

  METHOD delete_job_tagging.
    DATA lv_job_id TYPE /aws1/s3cjobid.
    DATA lt_tags TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.
    DATA lo_result TYPE REF TO /aws1/cl_s3cgetjobtagresult.
    DATA lt_retrieved_tags TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.

    " Fail if setup failed
    IF av_setup_failed = abap_true.
      cl_abap_unit_assert=>fail( msg = 'Setup failed. Cannot run test.' ).
    ENDIF.

    " Create a new job for this test
    lv_job_id = create_batch_job_helper( '_deltag' ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_job_id
      msg = |Job ID should not be empty| ).

    " First add some tags
    lt_tags = VALUE /aws1/cl_s3cs3tag=>tt_s3tagset(
      ( NEW /aws1/cl_s3cs3tag( iv_key = 'TestTag' iv_value = 'TestValue' ) )
    ).

    ao_s3c->putjobtagging(
      iv_accountid = av_account_id
      iv_jobid = lv_job_id
      it_tags = lt_tags
    ).

    " Delete all job tags
    ao_s3c_actions->delete_job_tagging(
      iv_account_id = av_account_id
      iv_job_id = lv_job_id
    ).

    " Verify tags were deleted
    lo_result = ao_s3c->getjobtagging(
      iv_accountid = av_account_id
      iv_jobid = lv_job_id
    ).

    lt_retrieved_tags = lo_result->get_tags( ).
    cl_abap_unit_assert=>assert_initial(
      act = lt_retrieved_tags
      msg = |Tags should be empty after deletion| ).

    " Clean up - cancel the job
    TRY.
        ao_s3c->updatejobstatus(
          iv_accountid = av_account_id
          iv_jobid = lv_job_id
          iv_requestedjobstatus = 'Cancelled'
        ).
      CATCH /aws1/cx_rt_generic.
        " Job might not be cancellable
    ENDTRY.
  ENDMETHOD.

  METHOD wait_for_job_status.
    DATA lv_wait_count TYPE i.
    DATA lv_max_waits TYPE i.
    DATA lo_describe_result TYPE REF TO /aws1/cl_s3cdescribejobresult.
    DATA lv_current_status TYPE /aws1/s3cjobstatus.

    lv_wait_count = 0.
    lv_max_waits = 60.

    WHILE lv_wait_count < lv_max_waits.
      lo_describe_result = ao_s3c->describejob(
        iv_accountid = av_account_id
        iv_jobid = iv_job_id
      ).

      lv_current_status = lo_describe_result->get_job( )->get_status( ).

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

    IF lv_wait_count >= lv_max_waits.
      cl_abap_unit_assert=>fail( msg = |Job did not reach status { iv_target_status } after 5 minutes| ).
    ENDIF.
  ENDMETHOD.

  METHOD create_batch_job_helper.
    DATA lv_manifest_location TYPE /aws1/s3cs3keyarnstring.
    DATA lv_report_bucket TYPE /aws1/s3cs3bucketarnstring.

    lv_manifest_location = |arn:aws:s3:::{ av_bucket_name }/job-manifest.csv|.
    lv_report_bucket = |arn:aws:s3:::{ av_bucket_name }|.

    rv_job_id = ao_s3c_actions->create_job(
      iv_account_id = av_account_id
      iv_role_arn = av_role_arn
      iv_manifest_location = lv_manifest_location
      iv_manifest_etag = av_manifest_etag
      iv_report_bucket = lv_report_bucket
    ).
  ENDMETHOD.
ENDCLASS.
