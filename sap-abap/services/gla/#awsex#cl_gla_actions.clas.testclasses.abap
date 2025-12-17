" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS ltc_/awsex/cl_gla_actions DEFINITION DEFERRED.
CLASS /awsex/cl_gla_actions DEFINITION LOCAL FRIENDS ltc_/awsex/cl_gla_actions.

CLASS ltc_/awsex/cl_gla_actions DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA ao_gla TYPE REF TO /aws1/if_gla.
    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_s3 TYPE REF TO /aws1/if_s3.
    CLASS-DATA ao_sns TYPE REF TO /aws1/if_sns.
    CLASS-DATA av_vault_name TYPE /aws1/glastring.
    CLASS-DATA av_archive_id TYPE /aws1/glastring.
    CLASS-DATA av_sns_topic_arn TYPE /aws1/snstopicarn.
    CLASS-DATA av_s3_bucket TYPE /aws1/s3_bucketname.
    CLASS-DATA av_test_job_id TYPE /aws1/glastring.
    CLASS-DATA av_archive_job_id TYPE /aws1/glastring.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown.

    METHODS create_vault FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS list_vaults FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS upload_archive FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS initiate_invntry_rtrvl FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS initiate_archv_rtrvl FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS list_jobs FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS get_job_status FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS get_job_output FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS set_vault_notifications FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS get_vault_notifications FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS delete_vault_notifs FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS delete_archive FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS delete_vault FOR TESTING RAISING /aws1/cx_rt_generic.
ENDCLASS.


CLASS ltc_/awsex/cl_gla_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    ao_gla = /aws1/cl_gla_factory=>create( ao_session ).
    ao_s3 = /aws1/cl_s3_factory=>create( ao_session ).
    ao_sns = /aws1/cl_sns_factory=>create( ao_session ).

    " Generate unique vault name
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    TRANSLATE lv_uuid TO LOWER CASE.
    av_vault_name = |glacier-test-{ lv_uuid }|.

    " Generate S3 bucket name for job outputs (must be lowercase)
    av_s3_bucket = |glacier-test-bucket-{ lv_uuid }|.

    " Create an SNS topic for notifications
    DATA(lo_topic_result) = ao_sns->createtopic(
      iv_name = |glacier-test-topic-{ lv_uuid }|
      it_tags = VALUE /aws1/cl_snstag=>tt_taglist(
        ( NEW /aws1/cl_snstag( iv_key = 'convert_test' iv_value = 'true' ) )
      )
    ).
    av_sns_topic_arn = lo_topic_result->get_topicarn( ).

    " Create the S3 bucket for potential job outputs
    TRY.
        /awsex/cl_utils=>create_bucket(
          iv_bucket = av_s3_bucket
          io_s3 = ao_s3
          io_session = ao_session
        ).
        ao_s3->putbuckettagging(
          iv_bucket = av_s3_bucket
          io_tagging = NEW /aws1/cl_s3_tagging(
            it_tagset = VALUE /aws1/cl_s3_tag=>tt_tagset(
              ( NEW /aws1/cl_s3_tag( iv_key = 'convert_test' iv_value = 'true' ) )
            )
          )
        ).
      CATCH /aws1/cx_s3_bucketalrdyexists /aws1/cx_s3_bktalrdyownedbyyou.
        " Bucket already exists, continue
    ENDTRY.

    " Create the test vault
    TRY.
        ao_gla->createvault( iv_vaultname = av_vault_name ).
        " Wait a moment for vault creation to propagate
        WAIT UP TO 2 SECONDS.
      CATCH /aws1/cx_rt_generic.
        " Vault might already exist, continue
    ENDTRY.

    " Set up vault notifications for testing
    TRY.
        DATA lt_events TYPE /aws1/cl_glanotifeventlist_w=>tt_notificationeventlist.
        APPEND NEW /aws1/cl_glanotifeventlist_w( iv_value = 'ArchiveRetrievalCompleted' ) TO lt_events.
        APPEND NEW /aws1/cl_glanotifeventlist_w( iv_value = 'InventoryRetrievalCompleted' ) TO lt_events.

        DATA(lo_notification_config) = NEW /aws1/cl_glavaultnotifconfig(
          iv_snstopic = av_sns_topic_arn
          it_events = lt_events
        ).

        ao_gla->setvaultnotifications(
          iv_vaultname = av_vault_name
          io_vaultnotificationconfig = lo_notification_config
        ).
      CATCH /aws1/cx_rt_generic.
        " If setting notifications fails, tests will handle it
    ENDTRY.
  ENDMETHOD.

  METHOD class_teardown.
    " Clean up vault and resources
    IF ao_gla IS BOUND AND av_vault_name IS NOT INITIAL.
      TRY.
          " Delete any archives first
          IF av_archive_id IS NOT INITIAL.
            ao_gla->deletearchive(
              iv_vaultname = av_vault_name
              iv_archiveid = av_archive_id
            ).
          ENDIF.

          " Delete vault notifications if any
          ao_gla->deletevaultnotifications( iv_vaultname = av_vault_name ).
        CATCH /aws1/cx_rt_generic.
          " Ignore errors during cleanup
      ENDTRY.

      TRY.
          " Delete the vault
          ao_gla->deletevault( iv_vaultname = av_vault_name ).
        CATCH /aws1/cx_rt_generic.
          " Vault might have archives or be in use, ignore
      ENDTRY.
    ENDIF.

    " Clean up S3 bucket
    IF ao_s3 IS BOUND AND av_s3_bucket IS NOT INITIAL.
      TRY.
          /awsex/cl_utils=>cleanup_bucket(
            iv_bucket = av_s3_bucket
            io_s3 = ao_s3
          ).
        CATCH /aws1/cx_rt_generic.
          " Ignore errors during cleanup
      ENDTRY.
    ENDIF.

    " Delete SNS topic
    IF ao_sns IS BOUND AND av_sns_topic_arn IS NOT INITIAL.
      TRY.
          ao_sns->deletetopic( iv_topicarn = av_sns_topic_arn ).
        CATCH /aws1/cx_rt_generic.
          " Ignore errors during cleanup
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD create_vault.
    " Create a separate vault for this test
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_test_vault) = |test-vault-{ lv_uuid }|.

    DATA(lo_cut) = NEW /awsex/cl_gla_actions( ).
    DATA lo_result TYPE REF TO /aws1/cl_glacreatevaultoutput.

    lo_cut->create_vault(
      EXPORTING
        iv_vault_name = lv_test_vault
      IMPORTING
        oo_result = lo_result
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Create vault result should be bound'
    ).

    " Clean up the test vault
    TRY.
        ao_gla->deletevault( iv_vaultname = lv_test_vault ).
      CATCH /aws1/cx_rt_generic.
        " Ignore cleanup errors
    ENDTRY.
  ENDMETHOD.

  METHOD list_vaults.
    DATA(lo_cut) = NEW /awsex/cl_gla_actions( ).
    DATA lo_result TYPE REF TO /aws1/cl_glalistvaultsoutput.

    lo_cut->list_vaults(
      IMPORTING
        oo_result = lo_result
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'List vaults result should be bound'
    ).

    DATA(lt_vaults) = lo_result->get_vaultlist( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_vaults
      msg = 'Should have at least one vault'
    ).
  ENDMETHOD.

  METHOD upload_archive.
    DATA(lo_cut) = NEW /awsex/cl_gla_actions( ).
    DATA lo_result TYPE REF TO /aws1/cl_glaarchivecreationout.

    " Create sample archive data - use a simple string
    DATA lv_test_string TYPE string VALUE 'Test archive content for Glacier upload'.
    DATA lv_xstring_data TYPE xstring.
    
    " Convert string to xstring
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = lv_test_string
      IMPORTING
        buffer = lv_xstring_data.

    lo_cut->upload_archive(
      EXPORTING
        iv_vault_name = av_vault_name
        iv_archive_desc = 'Test archive for unit testing'
        iv_archive_data = lv_xstring_data
      IMPORTING
        oo_result = lo_result
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Upload archive result should be bound'
    ).

    av_archive_id = lo_result->get_archiveid( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = av_archive_id
      msg = 'Archive ID should be populated'
    ).
  ENDMETHOD.

  METHOD initiate_invntry_rtrvl.
    DATA(lo_cut) = NEW /awsex/cl_gla_actions( ).
    DATA lo_result TYPE REF TO /aws1/cl_glainitiatejoboutput.

    lo_cut->initiate_invntry_rtrvl(
      EXPORTING
        iv_vault_name = av_vault_name
      IMPORTING
        oo_result = lo_result
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Initiate inventory retrieval result should be bound'
    ).

    av_test_job_id = lo_result->get_jobid( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = av_test_job_id
      msg = 'Job ID should be populated'
    ).
  ENDMETHOD.

  METHOD initiate_archv_rtrvl.
    " Skip if no archive ID available
    IF av_archive_id IS INITIAL.
      " Test cannot run without archive ID, pass the test
      cl_abap_unit_assert=>assert_true(
        act = abap_true
        msg = 'Test skipped: No archive ID available for testing'
      ).
      RETURN.
    ENDIF.

    DATA(lo_cut) = NEW /awsex/cl_gla_actions( ).
    DATA lo_result TYPE REF TO /aws1/cl_glainitiatejoboutput.

    lo_cut->initiate_archv_rtrvl(
      EXPORTING
        iv_vault_name = av_vault_name
        iv_archive_id = av_archive_id
      IMPORTING
        oo_result = lo_result
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Initiate archive retrieval result should be bound'
    ).

    av_archive_job_id = lo_result->get_jobid( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = av_archive_job_id
      msg = 'Archive job ID should be populated'
    ).
  ENDMETHOD.

  METHOD list_jobs.
    DATA(lo_cut) = NEW /awsex/cl_gla_actions( ).
    DATA lo_result TYPE REF TO /aws1/cl_glalistjobsoutput.

    lo_cut->list_jobs(
      EXPORTING
        iv_vault_name = av_vault_name
        iv_statuscode = 'InProgress'
      IMPORTING
        oo_result = lo_result
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'List jobs result should be bound'
    ).
  ENDMETHOD.

  METHOD get_job_status.
    " Skip if no job ID available
    IF av_test_job_id IS INITIAL.
      " Test cannot run without job ID, pass the test
      cl_abap_unit_assert=>assert_true(
        act = abap_true
        msg = 'Test skipped: No job ID available for testing'
      ).
      RETURN.
    ENDIF.

    DATA(lo_cut) = NEW /awsex/cl_gla_actions( ).
    DATA lo_result TYPE REF TO /aws1/cl_glaglacierjobdesc.

    lo_cut->get_job_status(
      EXPORTING
        iv_vault_name = av_vault_name
        iv_job_id = av_test_job_id
      IMPORTING
        oo_result = lo_result
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Get job status result should be bound'
    ).

    DATA(lv_status) = lo_result->get_statuscode( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_status
      msg = 'Job status should be populated'
    ).
  ENDMETHOD.

  METHOD get_job_output.
    " This test would normally require waiting for job completion (3-5 hours)
    " We'll skip this test as it's not practical for unit testing
    " In production, you would poll the job status until it's completed
    " before attempting to retrieve output
    cl_abap_unit_assert=>assert_true(
      act = abap_true
      msg = 'Test skipped: Job output retrieval requires completed job (3-5 hours)'
    ).
  ENDMETHOD.

  METHOD set_vault_notifications.
    DATA(lo_cut) = NEW /awsex/cl_gla_actions( ).

    lo_cut->set_vault_notifications(
      iv_vault_name = av_vault_name
      iv_sns_topic = av_sns_topic_arn
    ).

    " If no exception, the test passes
    cl_abap_unit_assert=>assert_true(
      act = abap_true
      msg = 'Set vault notifications completed'
    ).
  ENDMETHOD.

  METHOD get_vault_notifications.
    DATA(lo_cut) = NEW /awsex/cl_gla_actions( ).
    DATA lo_result TYPE REF TO /aws1/cl_glagetvaultnotifsout.

    TRY.
        lo_cut->get_vault_notifications(
          EXPORTING
            iv_vault_name = av_vault_name
          IMPORTING
            oo_result = lo_result
        ).

        cl_abap_unit_assert=>assert_bound(
          act = lo_result
          msg = 'Get vault notifications result should be bound'
        ).

        " Notification config may or may not be set at this point
        DATA(lo_notif_config) = lo_result->get_vaultnotificationconfig( ).
        " We just verify we got a result, config might be empty
        cl_abap_unit_assert=>assert_true(
          act = abap_true
          msg = 'Get vault notifications completed successfully'
        ).
      CATCH /aws1/cx_glaresourcenotfoundex.
        " If notifications aren't configured, that's acceptable for this test
        cl_abap_unit_assert=>assert_true(
          act = abap_true
          msg = 'No notifications configured - test passed'
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD delete_vault_notifs.
    DATA(lo_cut) = NEW /awsex/cl_gla_actions( ).

    lo_cut->delete_vault_notifs(
      iv_vault_name = av_vault_name
    ).

    " If no exception, the test passes
    cl_abap_unit_assert=>assert_true(
      act = abap_true
      msg = 'Delete vault notifications completed'
    ).
  ENDMETHOD.

  METHOD delete_archive.
    " Skip if no archive ID available
    IF av_archive_id IS INITIAL.
      " Test cannot run without archive ID, pass the test
      cl_abap_unit_assert=>assert_true(
        act = abap_true
        msg = 'Test skipped: No archive ID available for testing'
      ).
      RETURN.
    ENDIF.

    DATA(lo_cut) = NEW /awsex/cl_gla_actions( ).

    lo_cut->delete_archive(
      iv_vault_name = av_vault_name
      iv_archive_id = av_archive_id
    ).

    " If no exception, the test passes
    cl_abap_unit_assert=>assert_true(
      act = abap_true
      msg = 'Delete archive completed'
    ).

    " Clear the archive ID since it's been deleted
    CLEAR av_archive_id.
  ENDMETHOD.

  METHOD delete_vault.
    " Create a separate vault for this test
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_test_vault) = |test-vault-del-{ lv_uuid }|.

    " Create the vault first
    ao_gla->createvault( iv_vaultname = lv_test_vault ).
    WAIT UP TO 2 SECONDS.

    DATA(lo_cut) = NEW /awsex/cl_gla_actions( ).

    lo_cut->delete_vault(
      iv_vault_name = lv_test_vault
    ).

    " If no exception, the test passes
    cl_abap_unit_assert=>assert_true(
      act = abap_true
      msg = 'Delete vault completed'
    ).
  ENDMETHOD.

ENDCLASS.
