" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS /awsex/cl_sts_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS assume_role
      IMPORTING
        !iv_role_arn           TYPE /aws1/stsarntype
        !iv_role_session_name  TYPE /aws1/stsrolesessionnametype
        !iv_serial_number      TYPE /aws1/stsserialnumbertype OPTIONAL
        !iv_token_code         TYPE /aws1/ststokencodetype OPTIONAL
        !iv_duration_seconds   TYPE /aws1/stsroledursecondstype OPTIONAL
      EXPORTING
        !oo_result             TYPE REF TO /aws1/cl_stsassumeroleresponse
      RAISING
        /aws1/cx_rt_generic.

    METHODS get_session_token
      IMPORTING
        !iv_serial_number    TYPE /aws1/stsserialnumbertype OPTIONAL
        !iv_token_code       TYPE /aws1/ststokencodetype OPTIONAL
        !iv_duration_seconds TYPE /aws1/stsdurationsecondstype OPTIONAL
      EXPORTING
        !oo_result           TYPE REF TO /aws1/cl_stsgetsessiontokenrsp
      RAISING
        /aws1/cx_rt_generic.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /AWSEX/CL_STS_ACTIONS IMPLEMENTATION.


  METHOD assume_role.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_sts) = /aws1/cl_sts_factory=>create( lo_session ).

    " snippet-start:[sts.abapv1.assume_role]
    TRY.
        oo_result = lo_sts->assumerole(           " oo_result is returned for testing purposes. "
          iv_rolearn = iv_role_arn
          iv_rolesessionname = iv_role_session_name
          iv_serialnumber = iv_serial_number
          iv_tokencode = iv_token_code
          iv_durationseconds = iv_duration_seconds
        ).
        " Credentials can be retrieved from the result object
        DATA(lo_credentials) = oo_result->get_credentials( ).
        DATA(lv_access_key_id) = lo_credentials->get_accesskeyid( ).
        DATA(lv_secret_access_key) = lo_credentials->get_secretaccesskey( ).
        DATA(lv_session_token) = lo_credentials->get_sessiontoken( ).
        DATA(lv_expiration) = lo_credentials->get_expiration( ).
        MESSAGE 'Successfully assumed role.' TYPE 'I'.
      CATCH /aws1/cx_stsexpiredtokenex.
        MESSAGE 'The security token included in the request is expired.' TYPE 'E'.
      CATCH /aws1/cx_stsmalformedplydocex.
        MESSAGE 'The request was rejected because the policy document was malformed.' TYPE 'E'.
      CATCH /aws1/cx_stspackedplytoolarg00.
        MESSAGE 'The request was rejected because the total packed size of the session policies exceeds the limit.' TYPE 'E'.
      CATCH /aws1/cx_stsregiondisabledex.
        MESSAGE 'The STS service endpoint in this region is disabled.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[sts.abapv1.assume_role]
  ENDMETHOD.


  METHOD get_session_token.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_sts) = /aws1/cl_sts_factory=>create( lo_session ).

    " snippet-start:[sts.abapv1.get_session_token]
    TRY.
        oo_result = lo_sts->getsessiontoken(      " oo_result is returned for testing purposes. "
          iv_serialnumber = iv_serial_number
          iv_tokencode = iv_token_code
          iv_durationseconds = iv_duration_seconds
        ).
        " Credentials can be retrieved from the result object
        DATA(lo_credentials) = oo_result->get_credentials( ).
        DATA(lv_access_key_id) = lo_credentials->get_accesskeyid( ).
        DATA(lv_secret_access_key) = lo_credentials->get_secretaccesskey( ).
        DATA(lv_session_token) = lo_credentials->get_sessiontoken( ).
        DATA(lv_expiration) = lo_credentials->get_expiration( ).
        MESSAGE 'Successfully obtained session token.' TYPE 'I'.
      CATCH /aws1/cx_stsregiondisabledex.
        MESSAGE 'The STS service endpoint in this region is disabled.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[sts.abapv1.get_session_token]
  ENDMETHOD.
ENDCLASS.
