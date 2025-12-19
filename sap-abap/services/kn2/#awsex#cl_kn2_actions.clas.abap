" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS /awsex/cl_kn2_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS create_application
      IMPORTING
        !iv_application_name     TYPE /aws1/kn2applicationname
        !iv_role_arn             TYPE /aws1/kn2rolearn
        !iv_runtime_environment  TYPE /aws1/kn2runtimeenvironment DEFAULT 'SQL-1_0'
      RETURNING
        VALUE(oo_result)         TYPE REF TO /aws1/cl_kn2creapplicationrsp
      RAISING
        /aws1/cx_rt_generic.

    METHODS delete_application
      IMPORTING
        !iv_application_name TYPE /aws1/kn2applicationname
        !iv_create_timestamp TYPE /aws1/kn2timestamp
      RAISING
        /aws1/cx_rt_generic.

    METHODS describe_application
      IMPORTING
        !iv_application_name TYPE /aws1/kn2applicationname
      RETURNING
        VALUE(oo_result)     TYPE REF TO /aws1/cl_kn2dscapplicationrsp
      RAISING
        /aws1/cx_rt_generic.

    METHODS describe_snapshot
      IMPORTING
        !iv_application_name TYPE /aws1/kn2applicationname
        !iv_snapshot_name    TYPE /aws1/kn2snapshotname
      RETURNING
        VALUE(oo_result)     TYPE REF TO /aws1/cl_kn2dscapplicationsn01
      RAISING
        /aws1/cx_rt_generic.

    METHODS discover_input_schema
      IMPORTING
        !iv_stream_arn TYPE /aws1/kn2resourcearn
        !iv_role_arn   TYPE /aws1/kn2rolearn
      RETURNING
        VALUE(oo_result) TYPE REF TO /aws1/cl_kn2discoverinpschrsp
      RAISING
        /aws1/cx_rt_generic.

    METHODS add_input
      IMPORTING
        !iv_application_name           TYPE /aws1/kn2applicationname
        !iv_current_application_vrs_id TYPE /aws1/kn2applicationversionid
        !iv_input_prefix               TYPE /aws1/kn2inappstreamname
        !iv_stream_arn                 TYPE /aws1/kn2resourcearn
        !io_input_schema               TYPE REF TO /aws1/cl_kn2sourceschema
      RETURNING
        VALUE(oo_result)               TYPE REF TO /aws1/cl_kn2addapplicationin01
      RAISING
        /aws1/cx_rt_generic.

    METHODS add_output
      IMPORTING
        !iv_application_name           TYPE /aws1/kn2applicationname
        !iv_current_application_vrs_id TYPE /aws1/kn2applicationversionid
        !iv_in_app_stream_name         TYPE /aws1/kn2inappstreamname
        !iv_output_arn                 TYPE /aws1/kn2resourcearn
      RETURNING
        VALUE(oo_result)               TYPE REF TO /aws1/cl_kn2addapplicationou01
      RAISING
        /aws1/cx_rt_generic.

    METHODS update_code
      IMPORTING
        !iv_application_name           TYPE /aws1/kn2applicationname
        !iv_current_application_vrs_id TYPE /aws1/kn2applicationversionid
        !iv_code                       TYPE /aws1/kn2textcontent
      RETURNING
        VALUE(oo_result)               TYPE REF TO /aws1/cl_kn2updapplicationrsp
      RAISING
        /aws1/cx_rt_generic.

    METHODS start_application
      IMPORTING
        !iv_application_name TYPE /aws1/kn2applicationname
        !iv_input_id         TYPE /aws1/kn2id
      RAISING
        /aws1/cx_rt_generic.

    METHODS stop_application
      IMPORTING
        !iv_application_name TYPE /aws1/kn2applicationname
      RAISING
        /aws1/cx_rt_generic.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /AWSEX/CL_KN2_ACTIONS IMPLEMENTATION.


  METHOD create_application.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_kn2) = /aws1/cl_kn2_factory=>create( lo_session ).

    " snippet-start:[kn2.abapv1.createapplication]
    TRY.
        " iv_application_name = 'MyKinesisAnalyticsApp'
        " iv_role_arn = 'arn:aws:iam::123456789012:role/MyKinesisAnalyticsRole'
        " iv_runtime_environment = 'SQL-1_0'
        oo_result = lo_kn2->createapplication(
            iv_applicationname = iv_application_name
            iv_runtimeenvironment = iv_runtime_environment
            iv_serviceexecutionrole = iv_role_arn ).
        MESSAGE 'Kinesis Data Analytics application created.' TYPE 'I'.
      CATCH /aws1/cx_kn2codevalidationex.
        MESSAGE 'Code validation error creating application.' TYPE 'E'.
      CATCH /aws1/cx_kn2concurrentmodex.
        MESSAGE 'Concurrent modification error.' TYPE 'E'.
      CATCH /aws1/cx_kn2invalidargumentex.
        MESSAGE 'Invalid argument provided.' TYPE 'E'.
      CATCH /aws1/cx_kn2invalidrequestex.
        MESSAGE 'Invalid request.' TYPE 'E'.
      CATCH /aws1/cx_kn2limitexceededex.
        MESSAGE 'Limit exceeded.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourceinuseex.
        MESSAGE 'Resource already in use.' TYPE 'E'.
      CATCH /aws1/cx_kn2toomanytagsex.
        MESSAGE 'Too many tags.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[kn2.abapv1.createapplication]
  ENDMETHOD.


  METHOD delete_application.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_kn2) = /aws1/cl_kn2_factory=>create( lo_session ).

    " snippet-start:[kn2.abapv1.deleteapplication]
    TRY.
        " iv_application_name = 'MyKinesisAnalyticsApp'
        lo_kn2->deleteapplication(
            iv_applicationname = iv_application_name
            iv_createtimestamp = iv_create_timestamp ).
        MESSAGE 'Kinesis Data Analytics application deleted.' TYPE 'I'.
      CATCH /aws1/cx_kn2concurrentmodex.
        MESSAGE 'Concurrent modification error.' TYPE 'E'.
      CATCH /aws1/cx_kn2invapplicationco00.
        MESSAGE 'Invalid application configuration.' TYPE 'E'.
      CATCH /aws1/cx_kn2invalidargumentex.
        MESSAGE 'Invalid argument provided.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourceinuseex.
        MESSAGE 'Resource is in use and cannot be deleted.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourcenotfoundex.
        MESSAGE 'Application not found.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[kn2.abapv1.deleteapplication]
  ENDMETHOD.


  METHOD describe_application.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_kn2) = /aws1/cl_kn2_factory=>create( lo_session ).

    " snippet-start:[kn2.abapv1.describeapplication]
    TRY.
        " iv_application_name = 'MyKinesisAnalyticsApp'
        oo_result = lo_kn2->describeapplication(
            iv_applicationname = iv_application_name ).
        DATA(lo_detail) = oo_result->get_applicationdetail( ).
        MESSAGE 'Retrieved metadata for application.' TYPE 'I'.
      CATCH /aws1/cx_kn2invalidargumentex.
        MESSAGE 'Invalid argument provided.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourcenotfoundex.
        MESSAGE 'Application not found.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[kn2.abapv1.describeapplication]
  ENDMETHOD.


  METHOD describe_snapshot.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_kn2) = /aws1/cl_kn2_factory=>create( lo_session ).

    " snippet-start:[kn2.abapv1.describeapplicationsnapshot]
    TRY.
        " iv_application_name = 'MyKinesisAnalyticsApp'
        " iv_snapshot_name = 'my-snapshot'
        oo_result = lo_kn2->describeapplicationsnapshot(
            iv_applicationname = iv_application_name
            iv_snapshotname = iv_snapshot_name ).
        DATA(lo_snapshot) = oo_result->get_snapshotdetails( ).
        MESSAGE 'Retrieved snapshot metadata.' TYPE 'I'.
      CATCH /aws1/cx_kn2invalidargumentex.
        MESSAGE 'Invalid argument provided.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourcenotfoundex.
        MESSAGE 'Snapshot not found.' TYPE 'E'.
      CATCH /aws1/cx_kn2unsupportedopex.
        MESSAGE 'Unsupported operation.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[kn2.abapv1.describeapplicationsnapshot]
  ENDMETHOD.


  METHOD discover_input_schema.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_kn2) = /aws1/cl_kn2_factory=>create( lo_session ).

    " snippet-start:[kn2.abapv1.discoverinputschema]
    TRY.
        " iv_stream_arn = 'arn:aws:kinesis:us-east-1:123456789012:stream/my-input-stream'
        " iv_role_arn = 'arn:aws:iam::123456789012:role/MyKinesisAnalyticsRole'
        DATA(lo_input_start_pos_conf) = NEW /aws1/cl_kn2inpstrtingpositi00(
            iv_inputstartingposition = 'NOW' ).
        oo_result = lo_kn2->discoverinputschema(
            iv_resourcearn = iv_stream_arn
            iv_serviceexecutionrole = iv_role_arn
            io_inputstartingpositionconf = lo_input_start_pos_conf ).
        DATA(lo_schema) = oo_result->get_inputschema( ).
        MESSAGE 'Discovered input schema for stream.' TYPE 'I'.
      CATCH /aws1/cx_kn2invalidargumentex.
        MESSAGE 'Invalid argument provided.' TYPE 'E'.
      CATCH /aws1/cx_kn2invalidrequestex.
        MESSAGE 'Invalid request.' TYPE 'E'.
      CATCH /aws1/cx_kn2resrcprovtpexcdex.
        MESSAGE 'Resource provisioned throughput exceeded.' TYPE 'E'.
      CATCH /aws1/cx_kn2serviceunavailex.
        MESSAGE 'Service unavailable.' TYPE 'E'.
      CATCH /aws1/cx_kn2unabletodetectsc00.
        MESSAGE 'Unable to detect schema.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[kn2.abapv1.discoverinputschema]
  ENDMETHOD.


  METHOD add_input.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_kn2) = /aws1/cl_kn2_factory=>create( lo_session ).

    " snippet-start:[kn2.abapv1.addapplicationinput]
    TRY.
        " iv_application_name = 'MyKinesisAnalyticsApp'
        " iv_input_prefix = 'SOURCE_SQL_STREAM'
        " iv_stream_arn = 'arn:aws:kinesis:us-east-1:123456789012:stream/my-input-stream'
        DATA(lo_kinesis_streams_input) = NEW /aws1/cl_kn2kinesisstrmsinput(
            iv_resourcearn = iv_stream_arn ).
        DATA(lo_input) = NEW /aws1/cl_kn2input(
            iv_nameprefix = iv_input_prefix
            io_kinesisstreamsinput = lo_kinesis_streams_input
            io_inputschema = io_input_schema ).
        oo_result = lo_kn2->addapplicationinput(
            iv_applicationname = iv_application_name
            iv_currentapplicationvrsid = iv_current_application_vrs_id
            io_input = lo_input ).
        MESSAGE 'Added input stream to application.' TYPE 'I'.
      CATCH /aws1/cx_kn2codevalidationex.
        MESSAGE 'Code validation error.' TYPE 'E'.
      CATCH /aws1/cx_kn2concurrentmodex.
        MESSAGE 'Concurrent modification error.' TYPE 'E'.
      CATCH /aws1/cx_kn2invalidargumentex.
        MESSAGE 'Invalid argument provided.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourceinuseex.
        MESSAGE 'Resource is in use.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourcenotfoundex.
        MESSAGE 'Application not found.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[kn2.abapv1.addapplicationinput]
  ENDMETHOD.


  METHOD add_output.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_kn2) = /aws1/cl_kn2_factory=>create( lo_session ).

    " snippet-start:[kn2.abapv1.addapplicationoutput]
    TRY.
        " iv_application_name = 'MyKinesisAnalyticsApp'
        " iv_in_app_stream_name = 'DESTINATION_SQL_STREAM'
        " iv_output_arn = 'arn:aws:kinesis:us-east-1:123456789012:stream/my-output-stream'
        DATA(lo_kinesis_streams_output) = NEW /aws1/cl_kn2kinesisstreamsout(
            iv_resourcearn = iv_output_arn ).
        DATA(lo_destination_schema) = NEW /aws1/cl_kn2destinationschema(
            iv_recordformattype = 'JSON' ).
        DATA(lo_output) = NEW /aws1/cl_kn2output(
            iv_name = iv_in_app_stream_name
            io_kinesisstreamsoutput = lo_kinesis_streams_output
            io_destinationschema = lo_destination_schema ).
        oo_result = lo_kn2->addapplicationoutput(
            iv_applicationname = iv_application_name
            iv_currentapplicationvrsid = iv_current_application_vrs_id
            io_output = lo_output ).
        MESSAGE 'Added output stream to application.' TYPE 'I'.
      CATCH /aws1/cx_kn2concurrentmodex.
        MESSAGE 'Concurrent modification error.' TYPE 'E'.
      CATCH /aws1/cx_kn2invalidargumentex.
        MESSAGE 'Invalid argument provided.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourceinuseex.
        MESSAGE 'Resource is in use.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourcenotfoundex.
        MESSAGE 'Application not found.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[kn2.abapv1.addapplicationoutput]
  ENDMETHOD.


  METHOD update_code.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_kn2) = /aws1/cl_kn2_factory=>create( lo_session ).

    " snippet-start:[kn2.abapv1.updateapplication]
    TRY.
        " iv_application_name = 'MyKinesisAnalyticsApp'
        " iv_code = 'CREATE OR REPLACE STREAM "DESTINATION_SQL_STREAM" ...'
        DATA(lo_code_content_update) = NEW /aws1/cl_kn2codecontentupdate(
            iv_textcontentupdate = iv_code ).
        DATA(lo_app_code_config_update) = NEW /aws1/cl_kn2applicationcodec02(
            iv_codecontenttypeupdate = 'PLAINTEXT'
            io_codecontentupdate = lo_code_content_update ).
        DATA(lo_application_conf_update) = NEW /aws1/cl_kn2applicationconfupd(
            io_applicationcodeconfupdate = lo_app_code_config_update ).
        oo_result = lo_kn2->updateapplication(
            iv_applicationname = iv_application_name
            iv_currentapplicationvrsid = iv_current_application_vrs_id
            io_applicationconfupdate = lo_application_conf_update ).
        MESSAGE 'Updated application code.' TYPE 'I'.
      CATCH /aws1/cx_kn2codevalidationex.
        MESSAGE 'Code validation error.' TYPE 'E'.
      CATCH /aws1/cx_kn2concurrentmodex.
        MESSAGE 'Concurrent modification error.' TYPE 'E'.
      CATCH /aws1/cx_kn2invapplicationco00.
        MESSAGE 'Invalid application configuration.' TYPE 'E'.
      CATCH /aws1/cx_kn2invalidargumentex.
        MESSAGE 'Invalid argument provided.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourceinuseex.
        MESSAGE 'Resource is in use.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourcenotfoundex.
        MESSAGE 'Application not found.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[kn2.abapv1.updateapplication]
  ENDMETHOD.


  METHOD start_application.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_kn2) = /aws1/cl_kn2_factory=>create( lo_session ).

    " snippet-start:[kn2.abapv1.startapplication]
    TRY.
        " iv_application_name = 'MyKinesisAnalyticsApp'
        " iv_input_id = '1.1'
        DATA(lo_input_start_pos_conf) = NEW /aws1/cl_kn2inpstrtingpositi00(
            iv_inputstartingposition = 'NOW' ).
        DATA(lo_sql_run_conf) = NEW /aws1/cl_kn2sqlrunconf(
            iv_inputid = iv_input_id
            io_inputstartingpositionconf = lo_input_start_pos_conf ).
        DATA lt_sql_run_confs TYPE /aws1/cl_kn2sqlrunconf=>tt_sqlrunconfigurations.
        APPEND lo_sql_run_conf TO lt_sql_run_confs.
        DATA(lo_run_conf) = NEW /aws1/cl_kn2runconfiguration(
            it_sqlrunconfigurations = lt_sql_run_confs ).
        lo_kn2->startapplication(
            iv_applicationname = iv_application_name
            io_runconfiguration = lo_run_conf ).
        MESSAGE 'Started Kinesis Data Analytics application.' TYPE 'I'.
      CATCH /aws1/cx_kn2invapplicationco00.
        MESSAGE 'Invalid application configuration.' TYPE 'E'.
      CATCH /aws1/cx_kn2invalidargumentex.
        MESSAGE 'Invalid argument provided.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourceinuseex.
        MESSAGE 'Resource is in use.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourcenotfoundex.
        MESSAGE 'Application not found.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[kn2.abapv1.startapplication]
  ENDMETHOD.


  METHOD stop_application.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_kn2) = /aws1/cl_kn2_factory=>create( lo_session ).

    " snippet-start:[kn2.abapv1.stopapplication]
    TRY.
        " iv_application_name = 'MyKinesisAnalyticsApp'
        lo_kn2->stopapplication(
            iv_applicationname = iv_application_name ).
        MESSAGE 'Stopped Kinesis Data Analytics application.' TYPE 'I'.
      CATCH /aws1/cx_kn2concurrentmodex.
        MESSAGE 'Concurrent modification error.' TYPE 'E'.
      CATCH /aws1/cx_kn2invapplicationco00.
        MESSAGE 'Invalid application configuration.' TYPE 'E'.
      CATCH /aws1/cx_kn2invalidargumentex.
        MESSAGE 'Invalid argument provided.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourceinuseex.
        MESSAGE 'Resource is in use.' TYPE 'E'.
      CATCH /aws1/cx_kn2resourcenotfoundex.
        MESSAGE 'Application not found.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[kn2.abapv1.stopapplication]
  ENDMETHOD.
ENDCLASS.
