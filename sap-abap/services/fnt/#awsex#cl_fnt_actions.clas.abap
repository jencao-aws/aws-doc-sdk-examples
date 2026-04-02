" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS /awsex/cl_fnt_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS list_distributions
      IMPORTING
        !iv_max_items     TYPE /aws1/fntinteger OPTIONAL
      RETURNING
        VALUE(oo_result) TYPE REF TO /aws1/cl_fntlstdistributionsrs
      RAISING
        /aws1/cx_rt_generic.

    METHODS update_distribution
      IMPORTING
        !iv_distribution_id TYPE /aws1/fntstring
        !iv_comment          TYPE /aws1/fntcommenttype
        !iv_if_match         TYPE /aws1/fntstring
      RETURNING
        VALUE(oo_result)    TYPE REF TO /aws1/cl_fntupdistributionrs
      RAISING
        /aws1/cx_rt_generic.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /AWSEX/CL_FNT_ACTIONS IMPLEMENTATION.


  METHOD list_distributions.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_fnt) = /aws1/cl_fnt_factory=>create( lo_session ).

    " snippet-start:[fnt.abapv1.list_distributions]
    TRY.
        " List CloudFront distributions.
        oo_result = lo_fnt->listdistributions(
          iv_maxitems = iv_max_items
        ).

        " Output distribution information.
        DATA(lo_distribution_list) = oo_result->get_distributionlist( ).
        IF lo_distribution_list IS NOT INITIAL.
          DATA lv_quantity TYPE /aws1/fntinteger.
          lv_quantity = lo_distribution_list->get_quantity( ).
          MESSAGE 'CloudFront distributions found: ' && lv_quantity TYPE 'I'.

          LOOP AT lo_distribution_list->get_items( ) INTO DATA(lo_distribution_summary).
            DATA(lv_domain_name) = lo_distribution_summary->get_domainname( ).
            DATA(lv_distribution_id) = lo_distribution_summary->get_id( ).
            DATA(lo_viewer_cert) = lo_distribution_summary->get_viewercertificate( ).

            MESSAGE 'Domain: ' && lv_domain_name && ', Distribution Id: ' && lv_distribution_id TYPE 'I'.

            IF lo_viewer_cert IS NOT INITIAL.
              DATA(lv_cert_source) = lo_viewer_cert->get_certificatesource( ).
              MESSAGE 'Certificate Source: ' && lv_cert_source TYPE 'I'.

              IF lv_cert_source = 'acm'.
                DATA(lv_certificate) = lo_viewer_cert->get_certificate( ).
                MESSAGE 'Certificate: ' && lv_certificate TYPE 'I'.
              ENDIF.
            ENDIF.
          ENDLOOP.
        ELSE.
          MESSAGE 'No CloudFront distributions detected.' TYPE 'I'.
        ENDIF.
      CATCH /aws1/cx_fntinvalidargument INTO DATA(lo_invalidargument_exception).
        DATA(lv_error) = lo_invalidargument_exception->if_message~get_text( ).
        MESSAGE lv_error TYPE 'E'.
    ENDTRY.
    " snippet-end:[fnt.abapv1.list_distributions]
  ENDMETHOD.


  METHOD update_distribution.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_fnt) = /aws1/cl_fnt_factory=>create( lo_session ).

    " snippet-start:[fnt.abapv1.update_distribution]
    TRY.
        " First, get the current distribution configuration.
        DATA(lo_get_result) = lo_fnt->getdistributionconfig(
          iv_id = iv_distribution_id
        ).

        DATA(lo_distribution_config) = lo_get_result->get_distributionconfig( ).
        DATA(lv_etag) = lo_get_result->get_etag( ).

        " Create a new distribution config with updated comment.
        DATA(lo_new_config) = NEW /aws1/cl_fntdistributionconfig(
          iv_callerreference = lo_distribution_config->get_callerreference( )
          io_aliases = lo_distribution_config->get_aliases( )
          iv_defaultrootobject = lo_distribution_config->get_defaultrootobject( )
          io_origins = lo_distribution_config->get_origins( )
          io_origingroups = lo_distribution_config->get_origingroups( )
          io_defaultcachebehavior = lo_distribution_config->get_defaultcachebehavior( )
          io_cachebehaviors = lo_distribution_config->get_cachebehaviors( )
          io_customerrorresponses = lo_distribution_config->get_customerrorresponses( )
          iv_comment = iv_comment
          io_logging = lo_distribution_config->get_logging( )
          iv_priceclass = lo_distribution_config->get_priceclass( )
          iv_enabled = lo_distribution_config->get_enabled( )
          io_viewercertificate = lo_distribution_config->get_viewercertificate( )
          io_restrictions = lo_distribution_config->get_restrictions( )
          iv_webaclid = lo_distribution_config->get_webaclid( )
          iv_httpversion = lo_distribution_config->get_httpversion( )
          iv_isipv6enabled = lo_distribution_config->get_isipv6enabled( )
        ).

        " Update the distribution with the modified configuration.
        oo_result = lo_fnt->updatedistribution(
          iv_id = iv_distribution_id
          io_distributionconfig = lo_new_config
          iv_ifmatch = lv_etag
        ).

        MESSAGE 'Successfully updated CloudFront distribution.' TYPE 'I'.
      CATCH /aws1/cx_fntaccessdenied INTO DATA(lo_access_exception).
        DATA(lv_error) = lo_access_exception->if_message~get_text( ).
        MESSAGE lv_error TYPE 'E'.
      CATCH /aws1/cx_fntnosuchdistribution INTO DATA(lo_nodist_exception).
        lv_error = lo_nodist_exception->if_message~get_text( ).
        MESSAGE lv_error TYPE 'E'.
      CATCH /aws1/cx_fntinvalidifmatchvrs INTO DATA(lo_ifmatch_exception).
        lv_error = lo_ifmatch_exception->if_message~get_text( ).
        MESSAGE lv_error TYPE 'E'.
    ENDTRY.
    " snippet-end:[fnt.abapv1.update_distribution]
  ENDMETHOD.
ENDCLASS.
