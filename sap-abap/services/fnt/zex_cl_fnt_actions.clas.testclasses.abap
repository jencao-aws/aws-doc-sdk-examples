" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS ltc_awsex_cl_fnt_actions DEFINITION DEFERRED.
CLASS /awsex/cl_fnt_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_fnt_actions.

CLASS ltc_awsex_cl_fnt_actions DEFINITION FOR TESTING DURATION SHORT RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA ao_fnt TYPE REF TO /aws1/if_fnt.
    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_fnt_actions TYPE REF TO /awsex/cl_fnt_actions.
    CLASS-DATA av_distribution_id TYPE /aws1/fntstring.
    CLASS-DATA av_etag TYPE /aws1/fntstring.
    CLASS-DATA av_original_comment TYPE /aws1/fntcommenttype.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic.

    METHODS list_distributions FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS update_distribution FOR TESTING RAISING /aws1/cx_rt_generic.

ENDCLASS.

CLASS ltc_awsex_cl_fnt_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
    ao_fnt = /aws1/cl_fnt_factory=>create( ao_session ).
    ao_fnt_actions = NEW /awsex/cl_fnt_actions( ).

    " Get the first available distribution ID for testing.
    " We assume at least one distribution exists in the account.
    TRY.
        DATA(lo_list_result) = ao_fnt->listdistributions( iv_maxitems = 1 ).
        DATA(lo_distribution_list) = lo_list_result->get_distributionlist( ).

        IF lo_distribution_list IS NOT INITIAL AND lo_distribution_list->get_quantity( ) > 0.
          LOOP AT lo_distribution_list->get_items( ) INTO DATA(lo_distribution_summary).
            av_distribution_id = lo_distribution_summary->get_id( ).
            EXIT.
          ENDLOOP.

          " Get current config to save original comment.
          DATA(lo_config_result) = ao_fnt->getdistributionconfig( iv_id = av_distribution_id ).
          av_etag = lo_config_result->get_etag( ).
          av_original_comment = lo_config_result->get_distributionconfig( )->get_comment( ).
        ELSE.
          " No distributions available - tests will be skipped.
          MESSAGE 'No CloudFront distributions found. Tests will be skipped.' TYPE 'I'.
        ENDIF.
      CATCH /aws1/cx_rt_generic INTO DATA(lo_exception).
        " Failed to get distribution - tests will be skipped.
        DATA(lv_error) = lo_exception->if_message~get_text( ).
        MESSAGE 'Failed to setup test: ' && lv_error TYPE 'I'.
    ENDTRY.
  ENDMETHOD.

  METHOD class_teardown.
    " Restore the original comment if it was modified.
    IF av_distribution_id IS NOT INITIAL AND av_original_comment IS NOT INITIAL.
      TRY.
          " Get the current config with latest ETag.
          DATA(lo_config_result) = ao_fnt->getdistributionconfig( iv_id = av_distribution_id ).
          DATA(lo_distribution_config) = lo_config_result->get_distributionconfig( ).
          DATA(lv_etag) = lo_config_result->get_etag( ).

          " Restore original comment.
          lo_distribution_config->set_comment( av_original_comment ).

          ao_fnt->updatedistribution(
            iv_id = av_distribution_id
            io_distributionconfig = lo_distribution_config
            iv_ifmatch = lv_etag
          ).
        CATCH /aws1/cx_rt_generic.
          " Ignore errors during teardown.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD list_distributions.
    " Skip test if no distribution is available.
    IF av_distribution_id IS INITIAL.
      MESSAGE 'Skipping test - no distributions available.' TYPE 'I'.
      RETURN.
    ENDIF.

    DATA(lo_result) = ao_fnt_actions->list_distributions( iv_max_items = 10 ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'ListDistributions returned no result' ).

    DATA(lo_distribution_list) = lo_result->get_distributionlist( ).
    cl_abap_unit_assert=>assert_bound(
      act = lo_distribution_list
      msg = 'Distribution list is not bound' ).

    DATA(lv_quantity) = lo_distribution_list->get_quantity( ).
    cl_abap_unit_assert=>assert_differs(
      act = lv_quantity
      exp = 0
      msg = 'No distributions found in list' ).

    " Verify the distribution items are present.
    DATA(lt_items) = lo_distribution_list->get_items( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_items
      msg = 'Distribution items list is empty' ).

    " Check that each distribution has required fields.
    LOOP AT lt_items INTO DATA(lo_distribution_summary).
      DATA(lv_domain_name) = lo_distribution_summary->get_domainname( ).
      DATA(lv_dist_id) = lo_distribution_summary->get_id( ).

      cl_abap_unit_assert=>assert_not_initial(
        act = lv_domain_name
        msg = 'Distribution domain name is empty' ).

      cl_abap_unit_assert=>assert_not_initial(
        act = lv_dist_id
        msg = 'Distribution ID is empty' ).
    ENDLOOP.
  ENDMETHOD.

  METHOD update_distribution.
    " Skip test if no distribution is available.
    IF av_distribution_id IS INITIAL.
      MESSAGE 'Skipping test - no distributions available.' TYPE 'I'.
      RETURN.
    ENDIF.

    " Create a unique test comment.
    DATA(lv_timestamp) = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ).
    DATA(lv_test_comment) = |Test comment updated at { lv_timestamp }|.

    " Get current ETag before update.
    DATA(lo_config_result) = ao_fnt->getdistributionconfig( iv_id = av_distribution_id ).
    DATA(lv_current_etag) = lo_config_result->get_etag( ).

    " Update the distribution.
    DATA(lo_result) = ao_fnt_actions->update_distribution(
      iv_distribution_id = av_distribution_id
      iv_comment = lv_test_comment
      iv_if_match = lv_current_etag
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'UpdateDistribution returned no result' ).

    " Verify the comment was updated by retrieving the distribution.
    DATA(lo_verify_result) = ao_fnt->getdistributionconfig( iv_id = av_distribution_id ).
    DATA(lo_verify_config) = lo_verify_result->get_distributionconfig( ).
    DATA(lv_updated_comment) = lo_verify_config->get_comment( ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_updated_comment
      exp = lv_test_comment
      msg = 'Distribution comment was not updated correctly' ).
  ENDMETHOD.

ENDCLASS.
