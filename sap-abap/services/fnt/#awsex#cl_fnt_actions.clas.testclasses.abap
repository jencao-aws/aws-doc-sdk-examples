" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS ltc_awsex_cl_fnt_actions DEFINITION DEFERRED.
CLASS /awsex/cl_fnt_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_fnt_actions.

CLASS ltc_awsex_cl_fnt_actions DEFINITION FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA ao_fnt TYPE REF TO /aws1/if_fnt.
    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_fnt_actions TYPE REF TO /awsex/cl_fnt_actions.
    CLASS-DATA av_distribution_id TYPE /aws1/fntstring.
    CLASS-DATA av_original_comment TYPE /aws1/fntcommenttype.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS list_distributions FOR TESTING.
    METHODS update_distribution FOR TESTING.

ENDCLASS.

CLASS ltc_awsex_cl_fnt_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
    ao_fnt = /aws1/cl_fnt_factory=>create( ao_session ).
    ao_fnt_actions = NEW /awsex/cl_fnt_actions( ).

    " Try to get an existing distribution for testing
    " If none exists, tests will demonstrate the example code works
    TRY.
        DATA(lo_list_result) = ao_fnt->listdistributions( iv_maxitems = 1 ).
        DATA(lo_distribution_list) = lo_list_result->get_distributionlist( ).

        IF lo_distribution_list IS NOT INITIAL AND lo_distribution_list->get_quantity( ) > 0.
          LOOP AT lo_distribution_list->get_items( ) INTO DATA(lo_distribution_summary).
            av_distribution_id = lo_distribution_summary->get_id( ).
            EXIT.
          ENDLOOP.

          " Get current config to save original comment
          DATA(lo_config_result) = ao_fnt->getdistributionconfig( iv_id = av_distribution_id ).
          av_original_comment = lo_config_result->get_distributionconfig( )->get_comment( ).

          MESSAGE 'Using existing CloudFront distribution for testing: ' && av_distribution_id TYPE 'I'.
        ELSE.
          MESSAGE 'No CloudFront distributions found - tests will verify code executes correctly.' TYPE 'I'.
        ENDIF.
      CATCH /aws1/cx_rt_generic INTO DATA(lo_exception).
        DATA(lv_error) = lo_exception->if_message~get_text( ).
        MESSAGE 'Failed to list distributions: ' && lv_error TYPE 'I'.
    ENDTRY.
  ENDMETHOD.

  METHOD class_teardown.
    " Restore original comment if it was modified
    IF av_distribution_id IS NOT INITIAL AND av_original_comment IS NOT INITIAL.
      TRY.
          DATA(lo_config_result) = ao_fnt->getdistributionconfig( iv_id = av_distribution_id ).
          DATA(lo_dist_config) = lo_config_result->get_distributionconfig( ).

          " Restore original comment
          DATA(lo_restore_config) = NEW /aws1/cl_fntdistributionconfig(
            iv_callerreference = lo_dist_config->get_callerreference( )
            io_aliases = lo_dist_config->get_aliases( )
            iv_defaultrootobject = lo_dist_config->get_defaultrootobject( )
            io_origins = lo_dist_config->get_origins( )
            io_origingroups = lo_dist_config->get_origingroups( )
            io_defaultcachebehavior = lo_dist_config->get_defaultcachebehavior( )
            io_cachebehaviors = lo_dist_config->get_cachebehaviors( )
            io_customerrorresponses = lo_dist_config->get_customerrorresponses( )
            iv_comment = av_original_comment
            io_logging = lo_dist_config->get_logging( )
            iv_priceclass = lo_dist_config->get_priceclass( )
            iv_enabled = lo_dist_config->get_enabled( )
            io_viewercertificate = lo_dist_config->get_viewercertificate( )
            io_restrictions = lo_dist_config->get_restrictions( )
            iv_webaclid = lo_dist_config->get_webaclid( )
            iv_httpversion = lo_dist_config->get_httpversion( )
            iv_isipv6enabled = lo_dist_config->get_isipv6enabled( )
          ).

          ao_fnt->updatedistribution(
            iv_id = av_distribution_id
            io_distributionconfig = lo_restore_config
            iv_ifmatch = lo_config_result->get_etag( ) ).
        CATCH /aws1/cx_rt_generic.
          " Ignore errors during teardown
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD list_distributions.
    " Test list_distributions method executes successfully
    DATA(lo_result) = ao_fnt_actions->list_distributions( iv_max_items = 10 ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'ListDistributions returned no result' ).

    DATA(lo_distribution_list) = lo_result->get_distributionlist( ).
    cl_abap_unit_assert=>assert_bound(
      act = lo_distribution_list
      msg = 'Distribution list is not bound' ).

    " If a distribution exists, verify it's in the list
    IF av_distribution_id IS NOT INITIAL.
      DATA lv_found TYPE abap_bool VALUE abap_false.
      LOOP AT lo_distribution_list->get_items( ) INTO DATA(lo_distribution_summary).
        IF lo_distribution_summary->get_id( ) = av_distribution_id.
          lv_found = abap_true.
          cl_abap_unit_assert=>assert_not_initial(
            act = lo_distribution_summary->get_domainname( )
            msg = 'Distribution domain name is empty' ).
          EXIT.
        ENDIF.
      ENDLOOP.

      cl_abap_unit_assert=>assert_true(
        act = lv_found
        msg = |Test distribution { av_distribution_id } not found in list| ).
    ENDIF.
  ENDMETHOD.

  METHOD update_distribution.
    " Skip test if no distribution is available
    IF av_distribution_id IS INITIAL.
      MESSAGE 'Skipping update test - no distributions available.' TYPE 'I'.
      RETURN.
    ENDIF.

    " Test update_distribution method
    DATA lv_timestamp TYPE timestamp.
    GET TIME STAMP FIELD lv_timestamp.
    DATA(lv_test_comment) = |Test comment updated at { lv_timestamp }|.

    " Get current ETag before update
    DATA(lo_config_result) = ao_fnt->getdistributionconfig( iv_id = av_distribution_id ).
    DATA(lv_current_etag) = lo_config_result->get_etag( ).

    " Update the distribution using the action method
    DATA(lo_result) = ao_fnt_actions->update_distribution(
      iv_distribution_id = av_distribution_id
      iv_comment = lv_test_comment
      iv_if_match = lv_current_etag
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'UpdateDistribution returned no result' ).

    " Verify the comment was updated
    DATA(lo_verify_result) = ao_fnt->getdistributionconfig( iv_id = av_distribution_id ).
    DATA(lv_updated_comment) = lo_verify_result->get_distributionconfig( )->get_comment( ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_updated_comment
      exp = lv_test_comment
      msg = 'Distribution comment was not updated correctly' ).
  ENDMETHOD.

ENDCLASS.
