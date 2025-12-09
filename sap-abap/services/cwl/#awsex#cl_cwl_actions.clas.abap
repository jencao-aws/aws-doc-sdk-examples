" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0

CLASS /awsex/cl_cwl_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " Start a CloudWatch Logs Insights query
    METHODS start_query
      IMPORTING
        !iv_log_group_name TYPE /aws1/cwlloggroupname
        !iv_start_time     TYPE /aws1/cwltimestamp
        !iv_end_time       TYPE /aws1/cwltimestamp
        !iv_query_string   TYPE /aws1/cwlquerystring
        !iv_limit          TYPE /aws1/cwleventslimit OPTIONAL
      RETURNING
        VALUE(oo_result)   TYPE REF TO /aws1/cl_cwlstartqueryresponse
      RAISING
        /aws1/cx_rt_generic .

    " Get the results of a CloudWatch Logs Insights query
    METHODS get_query_results
      IMPORTING
        !iv_query_id     TYPE /aws1/cwlqueryid
      RETURNING
        VALUE(oo_result) TYPE REF TO /aws1/cl_cwlgetqueryresultsrsp
      RAISING
        /aws1/cx_rt_generic .

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /AWSEX/CL_CWL_ACTIONS IMPLEMENTATION.


  METHOD start_query.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_cwl) = /aws1/cl_cwl_factory=>create( lo_session ).

    " snippet-start:[cwl.abapv1.start_query]
    TRY.
        oo_result = lo_cwl->startquery(
          iv_loggroupname = iv_log_group_name
          iv_starttime    = iv_start_time
          iv_endtime      = iv_end_time
          iv_querystring  = iv_query_string
          iv_limit        = iv_limit
        ).
        MESSAGE 'Query started successfully.' TYPE 'I'.
      CATCH /aws1/cx_cwlinvalidparameterex INTO DATA(lo_inv_param_ex).
        DATA(lv_error) = lo_inv_param_ex->get_text( ).
        MESSAGE lv_error TYPE 'E'.
      CATCH /aws1/cx_cwllimitexceededex INTO DATA(lo_limit_ex).
        lv_error = lo_limit_ex->get_text( ).
        MESSAGE lv_error TYPE 'E'.
      CATCH /aws1/cx_cwlmalformedqueryex INTO DATA(lo_malformed_ex).
        lv_error = lo_malformed_ex->get_text( ).
        MESSAGE lv_error TYPE 'E'.
      CATCH /aws1/cx_cwlresourcenotfoundex INTO DATA(lo_not_found_ex).
        lv_error = lo_not_found_ex->get_text( ).
        MESSAGE lv_error TYPE 'E'.
      CATCH /aws1/cx_cwlserviceunavailex INTO DATA(lo_unavail_ex).
        lv_error = lo_unavail_ex->get_text( ).
        MESSAGE lv_error TYPE 'E'.
    ENDTRY.
    " snippet-end:[cwl.abapv1.start_query]
  ENDMETHOD.


  METHOD get_query_results.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_cwl) = /aws1/cl_cwl_factory=>create( lo_session ).

    " snippet-start:[cwl.abapv1.get_query_results]
    TRY.
        oo_result = lo_cwl->getqueryresults(
          iv_queryid = iv_query_id
        ).
        MESSAGE 'Query results retrieved successfully.' TYPE 'I'.
      CATCH /aws1/cx_cwlinvalidparameterex INTO DATA(lo_inv_param_ex).
        DATA(lv_error) = lo_inv_param_ex->get_text( ).
        MESSAGE lv_error TYPE 'E'.
      CATCH /aws1/cx_cwlresourcenotfoundex INTO DATA(lo_not_found_ex).
        lv_error = lo_not_found_ex->get_text( ).
        MESSAGE lv_error TYPE 'E'.
      CATCH /aws1/cx_cwlserviceunavailex INTO DATA(lo_unavail_ex).
        lv_error = lo_unavail_ex->get_text( ).
        MESSAGE lv_error TYPE 'E'.
    ENDTRY.
    " snippet-end:[cwl.abapv1.get_query_results]
  ENDMETHOD.
ENDCLASS.
