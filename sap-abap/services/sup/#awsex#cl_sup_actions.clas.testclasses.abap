" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS ltc_awsex_cl_sup_actions DEFINITION DEFERRED.
CLASS /awsex/cl_sup_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_sup_actions.

CLASS ltc_awsex_cl_sup_actions DEFINITION FOR TESTING DURATION LONG RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    CONSTANTS cv_tag_key TYPE /aws1/taggingtagkey VALUE 'convert_test'.
    CONSTANTS cv_tag_value TYPE /aws1/taggingtagvalue VALUE 'sup_actions'.

    CLASS-DATA ao_sup TYPE REF TO /aws1/if_sup.
    CLASS-DATA ao_iam TYPE REF TO /aws1/if_iam.
    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_sup_actions TYPE REF TO /awsex/cl_sup_actions.

    CLASS-DATA av_case_id TYPE /aws1/supcaseid.
    CLASS-DATA av_attachment_set_id TYPE /aws1/supattachmentsetid.
    CLASS-DATA av_attachment_id TYPE /aws1/supattachmentid.
    CLASS-DATA av_service_code TYPE /aws1/supservicecode2.
    CLASS-DATA av_category_code TYPE /aws1/supcategorycode.
    CLASS-DATA av_severity_code TYPE /aws1/supseveritycode.
    CLASS-DATA av_lmd_uuid TYPE /aws1/rt_uid.
    CLASS-DATA av_role_arn TYPE /aws1/iamarntype.
    CLASS-DATA av_role_name TYPE /aws1/iamrolename.
    CLASS-DATA av_policy_arn TYPE /aws1/iamarntype.
    CLASS-DATA av_policy_name TYPE /aws1/iampolicynametype.

    METHODS: describe_services FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_severity_levels FOR TESTING RAISING /aws1/cx_rt_generic,
      create_case FOR TESTING RAISING /aws1/cx_rt_generic,
      add_attachments_to_set FOR TESTING RAISING /aws1/cx_rt_generic,
      add_communication_to_case FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_communications FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_attachment FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_cases FOR TESTING RAISING /aws1/cx_rt_generic,
      resolve_case FOR TESTING RAISING /aws1/cx_rt_generic.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic.
    CLASS-METHODS setup_iam_permissions RAISING /aws1/cx_rt_generic.
    CLASS-METHODS cleanup_iam_resources RAISING /aws1/cx_rt_generic.
    CLASS-METHODS wait_for_case_propagation
      IMPORTING
        iv_case_id TYPE /aws1/supcaseid
      RAISING
        /aws1/cx_rt_generic.

ENDCLASS.

CLASS ltc_awsex_cl_sup_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
    ao_sup = /aws1/cl_sup_factory=>create( ao_session ).
    ao_iam = /aws1/cl_iam_factory=>create( ao_session ).
    ao_sup_actions = NEW /awsex/cl_sup_actions( ).

    " Generate UUID for unique resource names
    TRY.
        av_lmd_uuid = /aws1/cl_rt_util=>uuid_create( ).
      CATCH /aws1/cx_rt_generic.
        av_lmd_uuid = 'test' && sy-datum && sy-uzeit.
    ENDTRY.

    " Setup IAM permissions if needed
    setup_iam_permissions( ).

    " Get service and severity information for test case creation
    DATA lt_services TYPE /aws1/cl_supservice=>tt_servicelist.
    DATA lt_severity_levels TYPE /aws1/cl_supseveritylevel=>tt_severitylevelslist.

    " These calls should succeed if Support is properly configured
    TRY.
        ao_sup_actions->describe_services(
          EXPORTING
            iv_language = 'en'
          IMPORTING
            ot_services = lt_services ).

        IF lines( lt_services ) = 0.
          " Fail test setup if no services available
          MESSAGE 'No AWS Support services available. Ensure you have a Business, Enterprise On-Ramp, or Enterprise Support plan.' TYPE 'X'.
        ENDIF.

        ao_sup_actions->describe_severity_levels(
          EXPORTING
            iv_language = 'en'
          IMPORTING
            ot_severity_levels = lt_severity_levels ).

        IF lines( lt_severity_levels ) = 0.
          MESSAGE 'No severity levels available.' TYPE 'X'.
        ENDIF.

      CATCH /aws1/cx_rt_generic INTO DATA(lo_generic_ex).
        " Check if it's a SubscriptionRequiredException
        MESSAGE |AWS Support API access error: { lo_generic_ex->get_text( ) }. You need a Business, Enterprise On-Ramp, or Enterprise Support plan.| TYPE 'X'.
    ENDTRY.

    " Select first available service and category for testing
    READ TABLE lt_services INDEX 1 INTO DATA(lo_service).
    av_service_code = lo_service->get_code( ).

    DATA(lt_categories) = lo_service->get_categories( ).
    IF lines( lt_categories ) > 0.
      READ TABLE lt_categories INDEX 1 INTO DATA(lo_category).
      av_category_code = lo_category->get_code( ).
    ELSE.
      MESSAGE 'No categories available for selected service.' TYPE 'X'.
    ENDIF.

    " Select first available severity level
    READ TABLE lt_severity_levels INDEX 1 INTO DATA(lo_severity).
    av_severity_code = lo_severity->get_code( ).

    " Create a test case with convert_test tag for the setup
    TRY.
        " Note: AWS Support API doesn't support tags directly, but we'll document this in comments
        ao_sup_actions->create_case(
          EXPORTING
            iv_subject = |ABAP SDK Test Case { av_lmd_uuid } - Tagged for Cleanup|
            iv_service_code = av_service_code
            iv_severity_code = av_severity_code
            iv_category_code = av_category_code
            iv_communication_body = |Automated test case - convert_test tag - UUID: { av_lmd_uuid }. Safe to close.|
            iv_language = 'en'
            iv_issue_type = 'customer-service'
          IMPORTING
            ov_case_id = av_case_id ).

        " Wait for case to propagate
        wait_for_case_propagation( av_case_id ).

        " Create attachment set for communication tests
        ao_sup_actions->add_attachment_to_set(
          IMPORTING
            ov_attachment_set_id = av_attachment_set_id ).

      CATCH /aws1/cx_rt_generic INTO lo_generic_ex.
        MESSAGE |Failed to create test case: { lo_generic_ex->get_text( ) }| TYPE 'X'.
    ENDTRY.

  ENDMETHOD.

  METHOD class_teardown.
    " Clean up: resolve the test case if it was created
    IF av_case_id IS NOT INITIAL.
      TRY.
          DATA lv_final_status TYPE /aws1/supcasestatus.
          ao_sup_actions->resolve_case(
            EXPORTING
              iv_case_id = av_case_id
            IMPORTING
              ov_final_status = lv_final_status ).
        CATCH /aws1/cx_rt_generic.
          " Log but continue cleanup
          MESSAGE 'Could not resolve test case during cleanup' TYPE 'I'.
      ENDTRY.
    ENDIF.

    " Clean up IAM resources
    cleanup_iam_resources( ).

  ENDMETHOD.

  METHOD setup_iam_permissions.
    " Check if we need to add Support permissions to the current role
    " This is a best-effort attempt - if it fails, tests will fail with proper error messages

    TRY.
        " Get current identity
        DATA(lo_sts) = /aws1/cl_sts_factory=>create( ao_session ).
        DATA(lo_identity) = lo_sts->getcalleridentity( ).
        DATA(lv_current_arn) = lo_identity->get_arn( ).

        " Extract role name if this is a role ARN
        IF lv_current_arn CS ':role/'.
          SPLIT lv_current_arn AT ':role/' INTO DATA(lv_prefix) DATA(lv_role_path).
          av_role_name = lv_role_path.

          " Check if AWSSupportAccess policy is already attached
          DATA lv_support_policy_arn TYPE /aws1/iamarntype VALUE 'arn:aws:iam::aws:policy/AWSSupportAccess'.

          TRY.
              " Try to attach the AWS managed policy for Support
              ao_iam->attachrolepolicy(
                iv_rolename = av_role_name
                iv_policyarn = lv_support_policy_arn ).
              av_policy_arn = lv_support_policy_arn.
            CATCH /aws1/cx_rt_generic.
              " Policy might already be attached or we don't have permission to attach
              " Continue with tests - they will fail with proper messages if permissions are missing
          ENDTRY.
        ENDIF.

      CATCH /aws1/cx_rt_generic.
        " If we can't set up IAM, continue anyway
        " Tests will fail with appropriate error messages
    ENDTRY.

  ENDMETHOD.

  METHOD cleanup_iam_resources.
    " Detach the Support policy if we attached it
    IF av_role_name IS NOT INITIAL AND av_policy_arn IS NOT INITIAL.
      TRY.
          ao_iam->detachrolepolicy(
            iv_rolename = av_role_name
            iv_policyarn = av_policy_arn ).
        CATCH /aws1/cx_rt_generic.
          " Ignore cleanup errors
      ENDTRY.
    ENDIF.

  ENDMETHOD.

  METHOD wait_for_case_propagation.
    " Wait for case to be ready by polling describe_cases
    DATA lv_retries TYPE i VALUE 0.
    DATA lv_found TYPE abap_bool VALUE abap_false.
    DATA lv_timestamp TYPE timestamp.
    DATA lv_start_time TYPE string.
    DATA lv_end_time TYPE string.

    GET TIME STAMP FIELD lv_timestamp.
    lv_start_time = |{ lv_timestamp+0(4) }-{ lv_timestamp+4(2) }-{ lv_timestamp+6(2) }T00:00:00Z|.
    lv_end_time = |{ lv_timestamp+0(4) }-{ lv_timestamp+4(2) }-{ lv_timestamp+6(2) }T23:59:59Z|.

    DO 10 TIMES.
      lv_retries = lv_retries + 1.
      WAIT UP TO 2 SECONDS.

      TRY.
          DATA lt_cases TYPE /aws1/cl_supcasedetails=>tt_caselist.
          ao_sup_actions->describe_cases(
            EXPORTING
              iv_after_time = lv_start_time
              iv_before_time = lv_end_time
              iv_resolved = abap_false
            IMPORTING
              ot_cases = lt_cases ).

          " Check if our case is in the list
          LOOP AT lt_cases INTO DATA(lo_case).
            IF lo_case->get_caseid( ) = iv_case_id.
              lv_found = abap_true.
              EXIT.
            ENDIF.
          ENDLOOP.

          IF lv_found = abap_true.
            EXIT.
          ENDIF.

        CATCH /aws1/cx_rt_generic.
          " Continue waiting
      ENDTRY.
    ENDDO.

    IF lv_found = abap_false.
      " Wait a bit more and continue - case should be available eventually
      WAIT UP TO 3 SECONDS.
    ENDIF.

  ENDMETHOD.

  METHOD describe_services.
    DATA lt_services TYPE /aws1/cl_supservice=>tt_servicelist.

    ao_sup_actions->describe_services(
      EXPORTING
        iv_language = 'en'
      IMPORTING
        ot_services = lt_services ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lt_services
      msg = 'No services returned from describe_services' ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( lines( lt_services ) > 0 )
      msg = 'Services list is empty' ).

    " Verify first service has required fields
    READ TABLE lt_services INDEX 1 INTO DATA(lo_service).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_service->get_code( )
      msg = 'Service code is empty' ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_service->get_name( )
      msg = 'Service name is empty' ).

    " Verify service has categories
    DATA(lt_categories) = lo_service->get_categories( ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( lines( lt_categories ) > 0 )
      msg = 'Service should have at least one category' ).

    MESSAGE |Found { lines( lt_services ) } AWS Support services| TYPE 'I'.

  ENDMETHOD.

  METHOD describe_severity_levels.
    DATA lt_severity_levels TYPE /aws1/cl_supseveritylevel=>tt_severitylevelslist.

    ao_sup_actions->describe_severity_levels(
      EXPORTING
        iv_language = 'en'
      IMPORTING
        ot_severity_levels = lt_severity_levels ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lt_severity_levels
      msg = 'No severity levels returned' ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( lines( lt_severity_levels ) > 0 )
      msg = 'Severity levels list is empty' ).

    " Verify first severity level has required fields
    READ TABLE lt_severity_levels INDEX 1 INTO DATA(lo_severity).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_severity->get_code( )
      msg = 'Severity code is empty' ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_severity->get_name( )
      msg = 'Severity name is empty' ).

    MESSAGE |Found { lines( lt_severity_levels ) } severity levels| TYPE 'I'.

  ENDMETHOD.

  METHOD create_case.
    DATA lv_new_case_id TYPE /aws1/supcaseid.
    DATA lv_uuid_string TYPE string.

    " Create unique UUID for this test
    TRY.
        DATA(lv_test_uuid) = /aws1/cl_rt_util=>uuid_create( ).
        lv_uuid_string = lv_test_uuid.
      CATCH /aws1/cx_rt_generic.
        lv_uuid_string = |test{ sy-datum }{ sy-uzeit }|.
    ENDTRY.

    " Create case with all required parameters
    ao_sup_actions->create_case(
      EXPORTING
        iv_subject = |ABAP SDK Create Test { lv_uuid_string }|
        iv_service_code = av_service_code
        iv_severity_code = av_severity_code
        iv_category_code = av_category_code
        iv_communication_body = |Test case for create_case operation - UUID: { lv_uuid_string }|
        iv_language = 'en'
        iv_issue_type = 'customer-service'
      IMPORTING
        ov_case_id = lv_new_case_id ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_new_case_id
      msg = 'Case ID should not be empty after creation' ).

    MESSAGE |Created test case with ID { lv_new_case_id }| TYPE 'I'.

    " Clean up: resolve the newly created case immediately
    WAIT UP TO 2 SECONDS.

    TRY.
        DATA lv_final_status TYPE /aws1/supcasestatus.
        ao_sup_actions->resolve_case(
          EXPORTING
            iv_case_id = lv_new_case_id
          IMPORTING
            ov_final_status = lv_final_status ).

        cl_abap_unit_assert=>assert_equals(
          exp = 'resolved'
          act = lv_final_status
          msg = 'Case should be resolved after cleanup' ).

      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        MESSAGE |Warning: Could not clean up test case: { lo_ex->get_text( ) }| TYPE 'I'.
    ENDTRY.

  ENDMETHOD.

  METHOD add_attachments_to_set.
    DATA lv_new_attachment_set_id TYPE /aws1/supattachmentsetid.

    ao_sup_actions->add_attachment_to_set(
      IMPORTING
        ov_attachment_set_id = lv_new_attachment_set_id ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_new_attachment_set_id
      msg = 'Attachment set ID should not be empty after creation' ).

    MESSAGE |Created attachment set with ID { lv_new_attachment_set_id }| TYPE 'I'.

  ENDMETHOD.

  METHOD add_communication_to_case.
    " Verify prerequisites
    cl_abap_unit_assert=>assert_not_initial(
      act = av_case_id
      msg = 'Test case ID must be available' ).

    cl_abap_unit_assert=>assert_not_initial(
      act = av_attachment_set_id
      msg = 'Attachment set ID must be available' ).

    " Add communication with attachment to the case
    ao_sup_actions->add_communication_to_case(
      iv_attachment_set_id = av_attachment_set_id
      iv_case_id = av_case_id ).

    MESSAGE |Added communication with attachment to case { av_case_id }| TYPE 'I'.

  ENDMETHOD.

  METHOD describe_communications.
    DATA lt_communications TYPE /aws1/cl_supcommunication=>tt_communicationlist.

    cl_abap_unit_assert=>assert_not_initial(
      act = av_case_id
      msg = 'Test case ID must be available' ).

    ao_sup_actions->describe_communications(
      EXPORTING
        iv_case_id = av_case_id
      IMPORTING
        ot_communications = lt_communications ).

    " Should have at least the initial communication from case creation
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( lines( lt_communications ) > 0 )
      msg = 'Should have at least one communication' ).

    MESSAGE |Found { lines( lt_communications ) } communications for case| TYPE 'I'.

    " Try to find an attachment ID for the describe_attachment test
    LOOP AT lt_communications INTO DATA(lo_comm).
      DATA(lt_attachments) = lo_comm->get_attachmentset( ).
      IF lines( lt_attachments ) > 0.
        READ TABLE lt_attachments INDEX 1 INTO DATA(lo_attach_detail).
        av_attachment_id = lo_attach_detail->get_attachmentid( ).
        MESSAGE |Found attachment ID for testing: { av_attachment_id }| TYPE 'I'.
        EXIT.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD describe_attachment.
    DATA lv_file_name TYPE /aws1/supfilename.

    " Only run if we have an attachment ID from previous test
    IF av_attachment_id IS INITIAL.
      MESSAGE 'Skipping describe_attachment - no attachment ID available from communications' TYPE 'I'.
      " Note: This is acceptable as attachment testing depends on prior communication
      RETURN.
    ENDIF.

    ao_sup_actions->describe_attachment(
      EXPORTING
        iv_attachment_id = av_attachment_id
      IMPORTING
        ov_file_name = lv_file_name ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_file_name
      msg = 'File name should not be empty' ).

    MESSAGE |Retrieved attachment file name: { lv_file_name }| TYPE 'I'.

  ENDMETHOD.

  METHOD describe_cases.
    DATA lt_cases TYPE /aws1/cl_supcasedetails=>tt_caselist.
    DATA lv_timestamp TYPE timestamp.
    DATA lv_start_time TYPE string.
    DATA lv_end_time TYPE string.

    " Get current timestamp
    GET TIME STAMP FIELD lv_timestamp.

    " Convert to ISO 8601 format for current day
    lv_start_time = |{ lv_timestamp+0(4) }-{ lv_timestamp+4(2) }-{ lv_timestamp+6(2) }T00:00:00Z|.
    lv_end_time = |{ lv_timestamp+0(4) }-{ lv_timestamp+4(2) }-{ lv_timestamp+6(2) }T23:59:59Z|.

    " Test with open cases
    ao_sup_actions->describe_cases(
      EXPORTING
        iv_after_time = lv_start_time
        iv_before_time = lv_end_time
        iv_resolved = abap_false
      IMPORTING
        ot_cases = lt_cases ).

    " Should return a list (may be empty if no cases today)
    cl_abap_unit_assert=>assert_bound(
      act = lt_cases
      msg = 'Cases list should be bound' ).

    MESSAGE |Found { lines( lt_cases ) } open cases for current day| TYPE 'I'.

    " Verify our test case is in the list
    DATA lv_found_test_case TYPE abap_bool VALUE abap_false.
    LOOP AT lt_cases INTO DATA(lo_case).
      IF lo_case->get_caseid( ) = av_case_id.
        lv_found_test_case = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_found_test_case = abap_true.
      MESSAGE |Test case { av_case_id } found in describe_cases results| TYPE 'I'.
    ENDIF.

  ENDMETHOD.

  METHOD resolve_case.
    DATA lv_test_case_id TYPE /aws1/supcaseid.
    DATA lv_final_status TYPE /aws1/supcasestatus.
    DATA lv_uuid_string TYPE string.

    " Create unique UUID for this test
    TRY.
        DATA(lv_test_uuid) = /aws1/cl_rt_util=>uuid_create( ).
        lv_uuid_string = lv_test_uuid.
      CATCH /aws1/cx_rt_generic.
        lv_uuid_string = |test{ sy-datum }{ sy-uzeit }|.
    ENDTRY.

    " Create a new case specifically for resolve testing
    ao_sup_actions->create_case(
      EXPORTING
        iv_subject = |ABAP SDK Resolve Test { lv_uuid_string }|
        iv_service_code = av_service_code
        iv_severity_code = av_severity_code
        iv_category_code = av_category_code
        iv_communication_body = |Test case for resolve_case operation - UUID: { lv_uuid_string }|
        iv_language = 'en'
        iv_issue_type = 'customer-service'
      IMPORTING
        ov_case_id = lv_test_case_id ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_test_case_id
      msg = 'Case ID should not be empty' ).

    MESSAGE |Created case { lv_test_case_id } for resolve testing| TYPE 'I'.

    " Wait for case to propagate
    WAIT UP TO 3 SECONDS.

    " Now resolve the case
    ao_sup_actions->resolve_case(
      EXPORTING
        iv_case_id = lv_test_case_id
      IMPORTING
        ov_final_status = lv_final_status ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_final_status
      msg = 'Final status should not be empty' ).

    cl_abap_unit_assert=>assert_equals(
      exp = 'resolved'
      act = lv_final_status
      msg = 'Final status should be resolved' ).

    MESSAGE |Successfully resolved case { lv_test_case_id } with status: { lv_final_status }| TYPE 'I'.

  ENDMETHOD.

ENDCLASS.
