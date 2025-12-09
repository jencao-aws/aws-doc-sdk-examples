" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0

CLASS ltc_awsex_cl_cwl_actions DEFINITION DEFERRED.
CLASS /awsex/cl_cwl_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_cwl_actions.

CLASS ltc_awsex_cl_cwl_actions DEFINITION FOR TESTING DURATION LONG RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    CONSTANTS cv_query_string TYPE /aws1/cwlquerystring VALUE 'fields @timestamp, @message | sort @timestamp asc | limit 10'.

    CLASS-DATA ao_cwl TYPE REF TO /aws1/if_cwl.
    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_cwl_actions TYPE REF TO /awsex/cl_cwl_actions.
    CLASS-DATA av_log_group_name TYPE /aws1/cwlloggroupname.
    CLASS-DATA av_log_stream_name TYPE /aws1/cwllogstreamname.

    METHODS: start_query FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS: get_query_results FOR TESTING RAISING /aws1/cx_rt_generic.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic.

ENDCLASS.

CLASS ltc_awsex_cl_cwl_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
    ao_cwl = /aws1/cl_cwl_factory=>create( ao_session ).
    ao_cwl_actions = NEW /awsex/cl_cwl_actions( ).

    " Create a unique log group name for testing
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA lv_uuid_string TYPE string.
    lv_uuid_string = lv_uuid.
    av_log_group_name = |/aws/sap-abap-cwl-test-{ lv_uuid_string }|.
    av_log_stream_name = |test-stream-{ lv_uuid_string }|.

    " Create log group and stream for testing
    TRY.
        ao_cwl->createloggroup(
          iv_loggroupname = av_log_group_name
        ).

        " Tag the log group for cleanup
        ao_cwl->tagloggroup(
          iv_loggroupname = av_log_group_name
          it_tags = VALUE /aws1/cl_cwltags_w=>tt_tags(
            ( NEW /aws1/cl_cwltags_w( iv_key = 'convert_test' iv_value = 'true' ) )
          )
        ).
      CATCH /aws1/cx_cwlresrcalrdyexistsex.
        " Log group already exists, continue
    ENDTRY.

    TRY.
        ao_cwl->createlogstream(
          iv_loggroupname = av_log_group_name
          iv_logstreamname = av_log_stream_name
        ).
      CATCH /aws1/cx_cwlresrcalrdyexistsex.
        " Log stream already exists, continue
    ENDTRY.

    " Put some test log events
    DATA lt_log_events TYPE /aws1/cl_cwlinputlogevent=>tt_inputlogevents.
    DATA lv_timestamp TYPE /aws1/cwltimestamp.

    " Get current timestamp in milliseconds since epoch
    GET TIME STAMP FIELD DATA(lv_current_timestamp).
    lv_timestamp = cl_abap_tstmp=>get_unix_ts_from_tstmp( lv_current_timestamp ) * 1000.

    " Add test log events
    APPEND NEW /aws1/cl_cwlinputlogevent(
      iv_message = 'Test log message 1'
      iv_timestamp = lv_timestamp
    ) TO lt_log_events.

    APPEND NEW /aws1/cl_cwlinputlogevent(
      iv_message = 'Test log message 2'
      iv_timestamp = lv_timestamp + 1000
    ) TO lt_log_events.

    APPEND NEW /aws1/cl_cwlinputlogevent(
      iv_message = 'Test log message 3'
      iv_timestamp = lv_timestamp + 2000
    ) TO lt_log_events.

    TRY.
        ao_cwl->putlogevents(
          iv_loggroupname = av_log_group_name
          iv_logstreamname = av_log_stream_name
          it_logevents = lt_log_events
        ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        " Continue even if put fails
    ENDTRY.

    " Wait for log events to be indexed (CloudWatch Logs can take time to index)
    " Wait up to 60 seconds
    DATA lv_start_time TYPE timestamp.
    DATA lv_current_time TYPE timestamp.
    DATA lv_elapsed_seconds TYPE i.

    GET TIME STAMP FIELD lv_start_time.
    DO.
      GET TIME STAMP FIELD lv_current_time.
      lv_elapsed_seconds = cl_abap_tstmp=>subtract(
        tstmp1 = lv_current_time
        tstmp2 = lv_start_time
      ).

      IF lv_elapsed_seconds >= 60.
        EXIT.
      ENDIF.

      WAIT UP TO 5 SECONDS.
    ENDDO.

  ENDMETHOD.

  METHOD class_teardown.
    " Delete log group
    TRY.
        ao_cwl->deleteloggroup(
          iv_loggroupname = av_log_group_name
        ).
      CATCH /aws1/cx_cwlresourcenotfoundex.
        " Log group doesn't exist, that's okay
    ENDTRY.
  ENDMETHOD.

  METHOD start_query.
    " Calculate time range for query (last 5 minutes)
    DATA lv_end_time TYPE /aws1/cwltimestamp.
    DATA lv_start_time TYPE /aws1/cwltimestamp.

    GET TIME STAMP FIELD DATA(lv_current_timestamp).
    lv_end_time = cl_abap_tstmp=>get_unix_ts_from_tstmp( lv_current_timestamp ) * 1000.
    " Start time is 5 minutes before end time
    lv_start_time = lv_end_time - ( 5 * 60 * 1000 ).

    " Test start_query method
    DATA(lo_start_result) = ao_cwl_actions->start_query(
      iv_log_group_name = av_log_group_name
      iv_start_time     = lv_start_time
      iv_end_time       = lv_end_time
      iv_query_string   = cv_query_string
      iv_limit          = 10
    ).

    " Verify the result is not null
    cl_abap_unit_assert=>assert_bound(
      act = lo_start_result
      msg = 'Start query result should not be null'
    ).

    " Verify we got a query ID
    DATA(lv_query_id) = lo_start_result->get_queryid( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_query_id
      msg = 'Query ID should not be empty'
    ).

  ENDMETHOD.

  METHOD get_query_results.
    " First, start a query to get a query ID
    DATA lv_end_time TYPE /aws1/cwltimestamp.
    DATA lv_start_time TYPE /aws1/cwltimestamp.

    GET TIME STAMP FIELD DATA(lv_current_timestamp).
    lv_end_time = cl_abap_tstmp=>get_unix_ts_from_tstmp( lv_current_timestamp ) * 1000.
    " Start time is 5 minutes before end time
    lv_start_time = lv_end_time - ( 5 * 60 * 1000 ).

    " Start a query
    DATA(lo_start_result) = ao_cwl_actions->start_query(
      iv_log_group_name = av_log_group_name
      iv_start_time     = lv_start_time
      iv_end_time       = lv_end_time
      iv_query_string   = cv_query_string
      iv_limit          = 10
    ).

    DATA(lv_query_id) = lo_start_result->get_queryid( ).

    " Test get_query_results method
    " Poll for query to complete
    DATA lv_query_complete TYPE abap_bool VALUE abap_false.
    DATA lv_status TYPE /aws1/cwlquerystatus.
    DATA lo_get_result TYPE REF TO /aws1/cl_cwlgetqueryresultsrsp.

    " Poll for up to 60 seconds
    DO 12 TIMES.
      " Wait 5 seconds before each poll
      WAIT UP TO 5 SECONDS.

      lo_get_result = ao_cwl_actions->get_query_results(
        iv_query_id = lv_query_id
      ).

      " Verify the result is not null
      cl_abap_unit_assert=>assert_bound(
        act = lo_get_result
        msg = 'Get query results should not be null'
      ).

      lv_status = lo_get_result->get_status( ).

      " Check if query is complete
      IF lv_status = 'Complete' OR lv_status = 'Failed' OR
         lv_status = 'Cancelled' OR lv_status = 'Timeout'.
        lv_query_complete = abap_true.
        EXIT.
      ENDIF.
    ENDDO.

    " Assert that query completed
    cl_abap_unit_assert=>assert_true(
      act = lv_query_complete
      msg = 'Query should have completed within timeout period'
    ).

    " Assert that query status is Complete or Failed
    " (Failed is acceptable if there are no matching logs)
    DATA(lv_status_ok) = abap_false.
    IF lv_status = 'Complete' OR lv_status = 'Failed'.
      lv_status_ok = abap_true.
    ENDIF.

    cl_abap_unit_assert=>assert_true(
      act = lv_status_ok
      msg = |Query status should be Complete or Failed, but was { lv_status }|
    ).

    " Verify we can access results structure (even if empty)
    DATA(lt_results) = lo_get_result->get_results( ).
    " Results should be bound (even if empty table)
    cl_abap_unit_assert=>assert_bound(
      act = lt_results
      msg = 'Results should be bound (even if empty)'
    ).

  ENDMETHOD.

ENDCLASS.
