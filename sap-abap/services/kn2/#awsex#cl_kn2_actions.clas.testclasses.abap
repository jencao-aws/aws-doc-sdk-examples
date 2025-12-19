" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS ltc_awsex_cl_kn2_actions DEFINITION DEFERRED.
CLASS /awsex/cl_kn2_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_kn2_actions.

CLASS ltc_awsex_cl_kn2_actions DEFINITION FOR TESTING DURATION LONG RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_kn2 TYPE REF TO /aws1/if_kn2.
    CLASS-DATA ao_kn2_actions TYPE REF TO /awsex/cl_kn2_actions.
    CLASS-DATA ao_iam TYPE REF TO /aws1/if_iam.
    CLASS-DATA ao_kns TYPE REF TO /aws1/if_kns.

    CLASS-DATA av_application_name TYPE /aws1/kn2applicationname.
    CLASS-DATA av_role_arn TYPE /aws1/kn2rolearn.
    CLASS-DATA av_role_name TYPE /aws1/iamrolenametype.
    CLASS-DATA av_input_stream_name TYPE /aws1/knsstreamname.
    CLASS-DATA av_output_stream_name TYPE /aws1/knsstreamname.
    CLASS-DATA av_input_stream_arn TYPE /aws1/kn2resourcearn.
    CLASS-DATA av_output_stream_arn TYPE /aws1/kn2resourcearn.
    CLASS-DATA av_application_version_id TYPE /aws1/kn2applicationversionid.
    CLASS-DATA av_input_id TYPE /aws1/kn2id.
    CLASS-DATA av_create_timestamp TYPE /aws1/kn2timestamp.
    CLASS-DATA av_snapshot_name TYPE /aws1/kn2snapshotname.

    METHODS create_application FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS describe_application FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS discover_input_schema FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS add_input FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS add_output FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS update_code FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS start_application FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS stop_application FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS describe_snapshot FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS delete_application FOR TESTING RAISING /aws1/cx_rt_generic.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic.

    METHODS wait_for_application_status
      IMPORTING
        iv_application_name TYPE /aws1/kn2applicationname
        iv_target_status    TYPE /aws1/kn2applicationstatus
        iv_max_wait_sec     TYPE i DEFAULT 300
      RAISING
        /aws1/cx_rt_generic.
ENDCLASS.

CLASS ltc_awsex_cl_kn2_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
    ao_kn2 = /aws1/cl_kn2_factory=>create( ao_session ).
    ao_kn2_actions = NEW /awsex/cl_kn2_actions( ).
    ao_iam = /aws1/cl_iam_factory=>create( ao_session ).
    ao_kns = /aws1/cl_kns_factory=>create( ao_session ).

    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_account_id) = ao_session->get_account_id( ).
    DATA(lv_region) = ao_session->get_region( ).

    CONCATENATE 'sap-abap-kn2-app-' lv_uuid INTO av_application_name.
    CONCATENATE 'sap-abap-kn2-role-' lv_uuid INTO av_role_name.
    CONCATENATE 'sap-abap-kn2-input-' lv_uuid INTO av_input_stream_name.
    CONCATENATE 'sap-abap-kn2-output-' lv_uuid INTO av_output_stream_name.

    " Create IAM role for Kinesis Analytics
    DATA(lv_trust_policy) = '{"Version":"2012-10-17","Statement":[' &&
                             '{"Effect":"Allow","Principal":' &&
                             '{"Service":"kinesisanalytics.amazonaws.com"},' &&
                             '"Action":"sts:AssumeRole"}]}'.
    DATA(lo_create_role_result) = ao_iam->createrole(
        iv_rolename = av_role_name
        iv_assumerolepolicydocument = lv_trust_policy
        it_tags = VALUE /aws1/cl_iamtag=>tt_taglisttype(
            ( NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) ) ) ).
    av_role_arn = lo_create_role_result->get_role( )->get_arn( ).

    " Create policy for Kinesis Analytics role
    DATA lv_input_resource TYPE string.
    DATA lv_output_resource TYPE string.
    CONCATENATE 'arn:aws:kinesis:' lv_region ':' lv_account_id ':stream/' av_input_stream_name
      INTO lv_input_resource.
    CONCATENATE 'arn:aws:kinesis:' lv_region ':' lv_account_id ':stream/' av_output_stream_name
      INTO lv_output_resource.

    DATA(lv_policy_doc) = '{"Version":"2012-10-17","Statement":[' &&
        '{"Sid":"ReadInputKinesis","Effect":"Allow",' &&
        '"Action":["kinesis:DescribeStream","kinesis:GetShardIterator","kinesis:GetRecords"],' &&
        '"Resource":"' && lv_input_resource && '"},' &&
        '{"Sid":"WriteOutputKinesis","Effect":"Allow",' &&
        '"Action":["kinesis:DescribeStream","kinesis:PutRecord","kinesis:PutRecords"],' &&
        '"Resource":"' && lv_output_resource && '"}]}'.

    DATA lv_policy_name TYPE string.
    CONCATENATE 'sap-abap-kn2-policy-' lv_uuid INTO lv_policy_name.
    DATA(lo_policy_result) = ao_iam->createpolicy(
        iv_policyname = lv_policy_name
        iv_policydocument = lv_policy_doc
        it_tags = VALUE /aws1/cl_iamtag=>tt_taglisttype(
            ( NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) ) ) ).

    ao_iam->attachrolepolicy(
        iv_rolename = av_role_name
        iv_policyarn = lo_policy_result->get_policy( )->get_arn( ) ).

    " Create input and output Kinesis streams
    ao_kns->createstream(
        iv_streamname = av_input_stream_name
        iv_shardcount = 1 ).

    " Tag input stream
    DATA lt_input_tags TYPE /aws1/cl_knstagmap_w=>tt_tagmap.
    DATA ls_input_tag TYPE /aws1/cl_knstagmap_w=>ts_tagmap_maprow.
    ls_input_tag-key = 'convert_test'.
    ls_input_tag-value = NEW /aws1/cl_knstagmap_w( iv_value = 'true' ).
    INSERT ls_input_tag INTO TABLE lt_input_tags.
    ao_kns->addtagstostream(
        iv_streamname = av_input_stream_name
        it_tags = lt_input_tags ).

    ao_kns->createstream(
        iv_streamname = av_output_stream_name
        iv_shardcount = 1 ).

    " Tag output stream
    DATA lt_output_tags TYPE /aws1/cl_knstagmap_w=>tt_tagmap.
    DATA ls_output_tag TYPE /aws1/cl_knstagmap_w=>ts_tagmap_maprow.
    ls_output_tag-key = 'convert_test'.
    ls_output_tag-value = NEW /aws1/cl_knstagmap_w( iv_value = 'true' ).
    INSERT ls_output_tag INTO TABLE lt_output_tags.
    ao_kns->addtagstostream(
        iv_streamname = av_output_stream_name
        it_tags = lt_output_tags ).

    " Wait for streams to become active
    DATA lv_stream_status TYPE /aws1/knsstreamstatus.
    DATA lv_wait_count TYPE i.

    " Wait for input stream - reduced to 24 iterations (2 minutes max)
    lv_wait_count = 0.
    DO 24 TIMES.
      lv_wait_count = lv_wait_count + 1.
      TRY.
          DATA(lo_stream_desc) = ao_kns->describestream( iv_streamname = av_input_stream_name ).
          lv_stream_status = lo_stream_desc->get_streamdescription( )->get_streamstatus( ).
          IF lv_stream_status = 'ACTIVE'.
            EXIT.
          ENDIF.
        CATCH /aws1/cx_knsresourcenotfoundex.
          " Stream not yet available
      ENDTRY.
      IF lv_wait_count >= 24.
        DATA lv_msg TYPE string.
        CONCATENATE 'Input stream' av_input_stream_name 'did not become active'
          INTO lv_msg SEPARATED BY space.
        cl_abap_unit_assert=>fail( msg = lv_msg ).
      ENDIF.
      WAIT UP TO 5 SECONDS.
    ENDDO.

    " Wait for output stream - reduced to 24 iterations (2 minutes max)
    lv_wait_count = 0.
    DO 24 TIMES.
      lv_wait_count = lv_wait_count + 1.
      TRY.
          lo_stream_desc = ao_kns->describestream( iv_streamname = av_output_stream_name ).
          lv_stream_status = lo_stream_desc->get_streamdescription( )->get_streamstatus( ).
          IF lv_stream_status = 'ACTIVE'.
            EXIT.
          ENDIF.
        CATCH /aws1/cx_knsresourcenotfoundex.
          " Stream not yet available
      ENDTRY.
      IF lv_wait_count >= 24.
        DATA lv_msg2 TYPE string.
        CONCATENATE 'Output stream' av_output_stream_name 'did not become active'
          INTO lv_msg2 SEPARATED BY space.
        cl_abap_unit_assert=>fail( msg = lv_msg2 ).
      ENDIF.
      WAIT UP TO 5 SECONDS.
    ENDDO.

    " Get stream ARNs
    lo_stream_desc = ao_kns->describestream( iv_streamname = av_input_stream_name ).
    av_input_stream_arn = lo_stream_desc->get_streamdescription( )->get_streamarn( ).

    lo_stream_desc = ao_kns->describestream( iv_streamname = av_output_stream_name ).
    av_output_stream_arn = lo_stream_desc->get_streamdescription( )->get_streamarn( ).

    " Wait for role propagation
    WAIT UP TO 10 SECONDS.

  ENDMETHOD.

  METHOD class_teardown.
    " Delete application if it exists
    IF av_application_name IS NOT INITIAL.
      TRY.
          DATA(lo_app_desc) = ao_kn2->describeapplication( iv_applicationname = av_application_name ).
          DATA(lo_app_detail) = lo_app_desc->get_applicationdetail( ).
          " Stop application if running
          IF lo_app_detail->get_applicationstatus( ) = 'RUNNING'.
            ao_kn2->stopapplication( iv_applicationname = av_application_name ).
            WAIT UP TO 30 SECONDS.
          ENDIF.
          " Delete application
          ao_kn2->deleteapplication(
              iv_applicationname = av_application_name
              iv_createtimestamp = lo_app_detail->get_createtimestamp( ) ).
        CATCH /aws1/cx_kn2resourcenotfoundex.
          " Application already deleted or doesn't exist
      ENDTRY.
    ENDIF.

    " Delete Kinesis streams - tagged for manual cleanup as they may take time
    IF av_input_stream_name IS NOT INITIAL.
      TRY.
          ao_kns->deletestream( iv_streamname = av_input_stream_name ).
        CATCH /aws1/cx_knsresourcenotfoundex.
      ENDTRY.
    ENDIF.

    IF av_output_stream_name IS NOT INITIAL.
      TRY.
          ao_kns->deletestream( iv_streamname = av_output_stream_name ).
        CATCH /aws1/cx_knsresourcenotfoundex.
      ENDTRY.
    ENDIF.

    " Detach and delete IAM policy and role
    IF av_role_name IS NOT INITIAL.
      TRY.
          DATA(lo_attached_policies) = ao_iam->listattachedrolepolicies( iv_rolename = av_role_name ).
          LOOP AT lo_attached_policies->get_attachedpolicies( ) INTO DATA(lo_policy).
            DATA(lv_policy_arn) = lo_policy->get_policyarn( ).
            ao_iam->detachrolepolicy(
                iv_rolename = av_role_name
                iv_policyarn = lv_policy_arn ).
            " Delete the policy if it's one we created
            IF lv_policy_arn CS 'sap-abap-kn2-policy'.
              ao_iam->deletepolicy( iv_policyarn = lv_policy_arn ).
            ENDIF.
          ENDLOOP.
          ao_iam->deleterole( iv_rolename = av_role_name ).
        CATCH /aws1/cx_iamnosuchentityex.
      ENDTRY.
    ENDIF.

  ENDMETHOD.

  METHOD create_application.
    DATA(lo_result) = ao_kn2_actions->create_application(
        iv_application_name = av_application_name
        iv_role_arn = av_role_arn
        iv_runtime_environment = 'SQL-1_0' ).

    cl_abap_unit_assert=>assert_bound(
        act = lo_result
        msg = 'Create application did not return a result' ).

    DATA(lo_app_detail) = lo_result->get_applicationdetail( ).
    cl_abap_unit_assert=>assert_equals(
        exp = av_application_name
        act = lo_app_detail->get_applicationname( )
        msg = 'Application name does not match' ).

    av_application_version_id = lo_app_detail->get_applicationversionid( ).
    av_create_timestamp = lo_app_detail->get_createtimestamp( ).

    " Wait for application to be ready - reduced timeout
    wait_for_application_status(
        iv_application_name = av_application_name
        iv_target_status = 'READY'
        iv_max_wait_sec = 120 ).

  ENDMETHOD.

  METHOD describe_application.
    " Skip if application wasn't created
    IF av_application_name IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Application name is not set - create_application may have failed' ).
    ENDIF.

    DATA(lo_result) = ao_kn2_actions->describe_application( av_application_name ).

    cl_abap_unit_assert=>assert_bound(
        act = lo_result
        msg = 'Describe application did not return a result' ).

    DATA(lo_app_detail) = lo_result->get_applicationdetail( ).
    cl_abap_unit_assert=>assert_equals(
        exp = av_application_name
        act = lo_app_detail->get_applicationname( )
        msg = 'Application name does not match' ).

    " Update version ID in case it changed
    av_application_version_id = lo_app_detail->get_applicationversionid( ).

  ENDMETHOD.

  METHOD discover_input_schema.
    " Put multiple test records into the input stream
    DATA lt_records TYPE /aws1/cl_knsputrecsreqentry=>tt_putrecordsrequestentrylist.
    
    DATA(lv_xstring_data1) = /aws1/cl_rt_util=>string_to_xstring(
      `{` &&
        `"price": 50.00,` &&
        `"ticker": "AAPL"` &&
      `}` ).
    DATA(lv_xstring_data2) = /aws1/cl_rt_util=>string_to_xstring(
      `{` &&
        `"price": 100.00,` &&
        `"ticker": "GOOGL"` &&
      `}` ).
    DATA(lv_xstring_data3) = /aws1/cl_rt_util=>string_to_xstring(
      `{` &&
        `"price": 150.00,` &&
        `"ticker": "MSFT"` &&
      `}` ).

    APPEND NEW /aws1/cl_knsputrecsreqentry(
        iv_data = lv_xstring_data1
        iv_partitionkey = 'partition1' ) TO lt_records.
    APPEND NEW /aws1/cl_knsputrecsreqentry(
        iv_data = lv_xstring_data2
        iv_partitionkey = 'partition2' ) TO lt_records.
    APPEND NEW /aws1/cl_knsputrecsreqentry(
        iv_data = lv_xstring_data3
        iv_partitionkey = 'partition3' ) TO lt_records.

    ao_kns->putrecords(
        iv_streamname = av_input_stream_name
        it_records = lt_records ).

    " Wait for records to propagate
    WAIT UP TO 5 SECONDS.

    " Discover the schema
    DATA(lo_result) = ao_kn2_actions->discover_input_schema(
        iv_stream_arn = av_input_stream_arn
        iv_role_arn = av_role_arn ).

    cl_abap_unit_assert=>assert_bound(
        act = lo_result
        msg = 'Discover input schema did not return a result' ).

    DATA(lo_schema) = lo_result->get_inputschema( ).
    cl_abap_unit_assert=>assert_bound(
        act = lo_schema
        msg = 'Input schema was not discovered' ).

  ENDMETHOD.

  METHOD add_input.
    " First discover the schema - put multiple records
    DATA lt_records TYPE /aws1/cl_knsputrecsreqentry=>tt_putrecordsrequestentrylist.
    
    " Add multiple records to ensure minimum threshold
    DATA(lv_xstring_data1) = /aws1/cl_rt_util=>string_to_xstring(
      `{` &&
        `"price": 50.00,` &&
        `"ticker": "AAPL"` &&
      `}` ).
    DATA(lv_xstring_data2) = /aws1/cl_rt_util=>string_to_xstring(
      `{` &&
        `"price": 100.00,` &&
        `"ticker": "GOOGL"` &&
      `}` ).
    DATA(lv_xstring_data3) = /aws1/cl_rt_util=>string_to_xstring(
      `{` &&
        `"price": 150.00,` &&
        `"ticker": "MSFT"` &&
      `}` ).

    APPEND NEW /aws1/cl_knsputrecsreqentry(
        iv_data = lv_xstring_data1
        iv_partitionkey = 'partition1' ) TO lt_records.
    APPEND NEW /aws1/cl_knsputrecsreqentry(
        iv_data = lv_xstring_data2
        iv_partitionkey = 'partition2' ) TO lt_records.
    APPEND NEW /aws1/cl_knsputrecsreqentry(
        iv_data = lv_xstring_data3
        iv_partitionkey = 'partition3' ) TO lt_records.

    ao_kns->putrecords(
        iv_streamname = av_input_stream_name
        it_records = lt_records ).

    " Wait for records to propagate
    WAIT UP TO 5 SECONDS.

    DATA(lo_discover_result) = ao_kn2->discoverinputschema(
        iv_resourcearn = av_input_stream_arn
        iv_serviceexecutionrole = av_role_arn
        io_inputstartingpositionconf = NEW /aws1/cl_kn2inpstrtingpositi00( iv_inputstartingposition = 'NOW' ) ).

    DATA(lo_schema) = lo_discover_result->get_inputschema( ).

    " Add input to application
    DATA(lo_result) = ao_kn2_actions->add_input(
        iv_application_name = av_application_name
        iv_current_application_vrs_id = av_application_version_id
        iv_input_prefix = 'SOURCE_SQL_STREAM'
        iv_stream_arn = av_input_stream_arn
        io_input_schema = lo_schema ).

    cl_abap_unit_assert=>assert_bound(
        act = lo_result
        msg = 'Add input did not return a result' ).

    " Update version ID
    av_application_version_id = lo_result->get_applicationversionid( ).

    " Get input ID for starting application later
    DATA(lt_input_descriptions) = lo_result->get_inputdescriptions( ).
    IF lines( lt_input_descriptions ) > 0.
      READ TABLE lt_input_descriptions INDEX 1 INTO DATA(lo_input_desc).
      av_input_id = lo_input_desc->get_inputid( ).
    ENDIF.

  ENDMETHOD.

  METHOD add_output.
    " Skip if no valid version ID
    IF av_application_version_id IS INITIAL OR av_application_version_id = 0.
      cl_abap_unit_assert=>fail( msg = 'Application version ID is not set - create_application may have failed' ).
    ENDIF.

    DATA(lo_result) = ao_kn2_actions->add_output(
        iv_application_name = av_application_name
        iv_current_application_vrs_id = av_application_version_id
        iv_in_app_stream_name = 'DESTINATION_SQL_STREAM'
        iv_output_arn = av_output_stream_arn ).

    cl_abap_unit_assert=>assert_bound(
        act = lo_result
        msg = 'Add output did not return a result' ).

    " Update version ID
    av_application_version_id = lo_result->get_applicationversionid( ).

  ENDMETHOD.

  METHOD update_code.
    " Skip if no valid version ID
    IF av_application_version_id IS INITIAL OR av_application_version_id = 0.
      cl_abap_unit_assert=>fail( msg = 'Application version ID is not set - create_application may have failed' ).
    ENDIF.

    " Simple SQL code that copies from input to output
    DATA(lv_sql_code) = 'CREATE OR REPLACE STREAM "DESTINATION_SQL_STREAM" (ticker VARCHAR(4), price DOUBLE);' &&
                        cl_abap_char_utilities=>newline &&
                        'CREATE OR REPLACE PUMP "STREAM_PUMP" AS' &&
                        cl_abap_char_utilities=>newline &&
                        'INSERT INTO "DESTINATION_SQL_STREAM"' &&
                        cl_abap_char_utilities=>newline &&
                        'SELECT STREAM ticker, price FROM "SOURCE_SQL_STREAM_001";'.

    DATA(lo_result) = ao_kn2_actions->update_code(
        iv_application_name = av_application_name
        iv_current_application_vrs_id = av_application_version_id
        iv_code = lv_sql_code ).

    cl_abap_unit_assert=>assert_bound(
        act = lo_result
        msg = 'Update code did not return a result' ).

    " Update version ID
    av_application_version_id = lo_result->get_applicationdetail( )->get_applicationversionid( ).

  ENDMETHOD.

  METHOD start_application.
    " Skip if application or input ID wasn't set
    IF av_application_name IS INITIAL OR av_input_id IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Application name or input ID is not set - previous tests may have failed' ).
    ENDIF.

    " Make sure application is ready
    wait_for_application_status(
        iv_application_name = av_application_name
        iv_target_status = 'READY'
        iv_max_wait_sec = 60 ).

    ao_kn2_actions->start_application(
        iv_application_name = av_application_name
        iv_input_id = av_input_id ).

    " Wait for application to be running - reduced timeout to 3 minutes
    wait_for_application_status(
        iv_application_name = av_application_name
        iv_target_status = 'RUNNING'
        iv_max_wait_sec = 180 ).

    " Verify application is running
    DATA(lo_app_desc) = ao_kn2->describeapplication( iv_applicationname = av_application_name ).
    cl_abap_unit_assert=>assert_equals(
        exp = 'RUNNING'
        act = lo_app_desc->get_applicationdetail( )->get_applicationstatus( )
        msg = 'Application did not start successfully' ).

  ENDMETHOD.

  METHOD stop_application.
    " Skip if application wasn't created
    IF av_application_name IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Application name is not set - create_application may have failed' ).
    ENDIF.

    ao_kn2_actions->stop_application( av_application_name ).

    " Wait for application to stop - reduced timeout
    wait_for_application_status(
        iv_application_name = av_application_name
        iv_target_status = 'READY'
        iv_max_wait_sec = 120 ).

    " Verify application is stopped
    DATA(lo_app_desc) = ao_kn2->describeapplication( iv_applicationname = av_application_name ).
    DATA(lv_status) = lo_app_desc->get_applicationdetail( )->get_applicationstatus( ).
    cl_abap_unit_assert=>assert_true(
        act = xsdbool( lv_status = 'READY' OR lv_status = 'STOPPING' )
        msg = 'Application did not stop successfully' ).

  ENDMETHOD.

  METHOD describe_snapshot.
    " Skip if application wasn't created
    IF av_application_name IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Application name is not set - create_application may have failed' ).
    ENDIF.

    " First create a snapshot of the application
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    CONCATENATE 'sap-kn2-snap-' lv_uuid INTO av_snapshot_name.

    " Make sure application is not running
    DATA(lo_app_desc) = ao_kn2->describeapplication( iv_applicationname = av_application_name ).
    DATA(lv_status) = lo_app_desc->get_applicationdetail( )->get_applicationstatus( ).

    IF lv_status = 'RUNNING'.
      ao_kn2->stopapplication( iv_applicationname = av_application_name ).
      wait_for_application_status(
          iv_application_name = av_application_name
          iv_target_status = 'READY'
          iv_max_wait_sec = 120 ).
    ENDIF.

    " Create a snapshot
    TRY.
        ao_kn2->createapplicationsnapshot(
            iv_applicationname = av_application_name
            iv_snapshotname = av_snapshot_name ).

        " Wait for snapshot to be ready - reduced to 24 iterations (2 minutes max)
        DATA lv_snapshot_status TYPE /aws1/kn2snapshotstatus.
        DATA lv_wait_count TYPE i VALUE 0.
        DO 24 TIMES.
          lv_wait_count = lv_wait_count + 1.
          DATA(lo_snap_desc) = ao_kn2->describeapplicationsnapshot(
              iv_applicationname = av_application_name
              iv_snapshotname = av_snapshot_name ).
          lv_snapshot_status = lo_snap_desc->get_snapshotdetails( )->get_snapshotstatus( ).
          IF lv_snapshot_status = 'READY'.
            EXIT.
          ENDIF.
          IF lv_wait_count >= 24.
            cl_abap_unit_assert=>fail( msg = 'Snapshot did not become ready' ).
          ENDIF.
          WAIT UP TO 5 SECONDS.
        ENDDO.

        " Test the describe_snapshot method
        DATA(lo_result) = ao_kn2_actions->describe_snapshot(
            iv_application_name = av_application_name
            iv_snapshot_name = av_snapshot_name ).

        cl_abap_unit_assert=>assert_bound(
            act = lo_result
            msg = 'Describe snapshot did not return a result' ).

        DATA(lo_snapshot) = lo_result->get_snapshotdetails( ).
        cl_abap_unit_assert=>assert_equals(
            exp = av_snapshot_name
            act = lo_snapshot->get_snapshotname( )
            msg = 'Snapshot name does not match' ).

        cl_abap_unit_assert=>assert_equals(
            exp = 'READY'
            act = lo_snapshot->get_snapshotstatus( )
            msg = 'Snapshot status is not READY' ).

        " Clean up snapshot
        ao_kn2->deleteapplicationsnapshot(
            iv_applicationname = av_application_name
            iv_snapshotname = av_snapshot_name ).

      CATCH /aws1/cx_kn2unsupportedopex.
        " Snapshots may not be supported for SQL-1_0 runtime
        MESSAGE 'Snapshot operations not supported for this runtime' TYPE 'I'.
    ENDTRY.

  ENDMETHOD.

  METHOD delete_application.
    " Skip if application wasn't created
    IF av_application_name IS INITIAL OR av_create_timestamp IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Application name or timestamp is not set - create_application may have failed' ).
    ENDIF.

    " Make sure application is not running
    DATA(lo_app_desc) = ao_kn2->describeapplication( iv_applicationname = av_application_name ).
    DATA(lv_status) = lo_app_desc->get_applicationdetail( )->get_applicationstatus( ).

    IF lv_status = 'RUNNING'.
      ao_kn2->stopapplication( iv_applicationname = av_application_name ).
      wait_for_application_status(
          iv_application_name = av_application_name
          iv_target_status = 'READY'
          iv_max_wait_sec = 120 ).
    ENDIF.

    ao_kn2_actions->delete_application(
        iv_application_name = av_application_name
        iv_create_timestamp = av_create_timestamp ).

    " Verify application is deleted
    DATA(lv_found) = abap_true.
    TRY.
        ao_kn2->describeapplication( iv_applicationname = av_application_name ).
      CATCH /aws1/cx_kn2resourcenotfoundex.
        lv_found = abap_false.
    ENDTRY.

    cl_abap_unit_assert=>assert_false(
        act = lv_found
        msg = 'Application was not deleted' ).

  ENDMETHOD.

  METHOD wait_for_application_status.
    DATA lv_wait_count TYPE i VALUE 0.
    DATA lv_current_status TYPE /aws1/kn2applicationstatus.
    DATA lv_max_iterations TYPE i.

    lv_max_iterations = iv_max_wait_sec / 10.
    IF lv_max_iterations < 1.
      lv_max_iterations = 1.
    ENDIF.

    DO lv_max_iterations TIMES.
      lv_wait_count = lv_wait_count + 1.

      TRY.
          DATA(lo_app_desc) = ao_kn2->describeapplication( iv_applicationname = iv_application_name ).
          lv_current_status = lo_app_desc->get_applicationdetail( )->get_applicationstatus( ).

          IF lv_current_status = iv_target_status.
            RETURN.
          ENDIF.

        CATCH /aws1/cx_kn2resourcenotfoundex.
          IF iv_target_status = 'DELETED'.
            RETURN.
          ENDIF.
      ENDTRY.

      IF lv_wait_count < lv_max_iterations.
        WAIT UP TO 10 SECONDS.
      ENDIF.
    ENDDO.

    " If we reach here, timeout occurred
    DATA lv_fail_msg TYPE string.
    CONCATENATE 'Application' iv_application_name 'did not reach status' iv_target_status 'within' iv_max_wait_sec 'seconds'
      INTO lv_fail_msg SEPARATED BY space.
    RAISE EXCEPTION TYPE /aws1/cx_rt_generic
      EXPORTING
        av_msgv1 = lv_fail_msg(50)
        av_msgv2 = iv_target_status.

  ENDMETHOD.

ENDCLASS.
