" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS ltc_awsex_cl_sts_actions DEFINITION DEFERRED.
CLASS /awsex/cl_sts_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_sts_actions.

CLASS ltc_awsex_cl_sts_actions DEFINITION FOR TESTING DURATION SHORT RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_sts TYPE REF TO /aws1/if_sts.
    CLASS-DATA ao_iam TYPE REF TO /aws1/if_iam.
    CLASS-DATA ao_sts_actions TYPE REF TO /awsex/cl_sts_actions.
    CLASS-DATA av_role_arn TYPE /aws1/stsarntype.
    CLASS-DATA av_role_name TYPE /aws1/iamrolenametype.
    CLASS-DATA av_policy_arn TYPE /aws1/iamarntype.

    " NOTE: get_session_token is not tested here because it requires IAM user credentials
    " (long-term access keys) and cannot be called with temporary/session credentials.
    " Most SAP ABAP SDK profiles use IAM role credentials (temporary), which makes
    " automated testing of GetSessionToken impractical. The method is provided for
    " documentation purposes to show developers how to use it when they have IAM user credentials.
    METHODS: assume_role FOR TESTING RAISING /aws1/cx_rt_generic.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic /awsex/cx_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic /awsex/cx_generic.

ENDCLASS.

CLASS ltc_awsex_cl_sts_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
    ao_sts = /aws1/cl_sts_factory=>create( ao_session ).
    ao_iam = /aws1/cl_iam_factory=>create( ao_session ).
    ao_sts_actions = NEW /awsex/cl_sts_actions( ).

    " Create a unique role name for testing using utils function
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA lv_uuid_string TYPE string.
    lv_uuid_string = lv_uuid.
    av_role_name = |abap-sts-role-{ lv_uuid_string }|.

    " Create a trust policy document allowing the account to assume this role
    DATA(lv_account_id) = ao_session->get_account_id( ).
    DATA(lv_trust_policy) = |\{\n| &&
      |  "Version": "2012-10-17",\n| &&
      |  "Statement": [\{\n| &&
      |    "Effect": "Allow",\n| &&
      |    "Principal": \{\n| &&
      |      "AWS": "arn:aws:iam::{ lv_account_id }:root"\n| &&
      |    \},\n| &&
      |    "Action": "sts:AssumeRole"\n| &&
      |  \}]\n| &&
      |\}|.

    TRY.
        " Create IAM role for testing AssumeRole - tagged with convert_test
        DATA(lo_create_role_result) = ao_iam->createrole(
          iv_rolename = av_role_name
          iv_assumerolepolicydocument = lv_trust_policy
          it_tags = VALUE /aws1/cl_iamtag=>tt_taglisttype(
            ( NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) )
          )
        ).

        av_role_arn = lo_create_role_result->get_role( )->get_arn( ).

        " Create and attach a policy that allows reading S3 buckets
        DATA(lv_policy_doc) = |\{\n| &&
          |  "Version": "2012-10-17",\n| &&
          |  "Statement": [\{\n| &&
          |    "Effect": "Allow",\n| &&
          |    "Action": "s3:ListAllMyBuckets",\n| &&
          |    "Resource": "*"\n| &&
          |  \}]\n| &&
          |\}|.

        DATA(lv_policy_name) = |abap-sts-policy-{ lv_uuid_string }|.
        " Create policy - tagged with convert_test
        DATA(lo_create_policy_result) = ao_iam->createpolicy(
          iv_policyname = lv_policy_name
          iv_policydocument = lv_policy_doc
          it_tags = VALUE /aws1/cl_iamtag=>tt_taglisttype(
            ( NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) )
          )
        ).

        av_policy_arn = lo_create_policy_result->get_policy( )->get_arn( ).

        " Attach the policy to the role
        ao_iam->attachrolepolicy(
          iv_rolename = av_role_name
          iv_policyarn = av_policy_arn
        ).

        " Wait for role to propagate - IAM resources can take time to become available
        DATA lv_wait_time TYPE i VALUE 10.
        WAIT UP TO lv_wait_time SECONDS.

      CATCH /aws1/cx_iamentityalrdyexex INTO DATA(lo_entity_exists).
        " If role or policy already exists from a failed previous test, try to retrieve it
        TRY.
            DATA(lo_existing_role) = ao_iam->getrole( iv_rolename = av_role_name ).
            av_role_arn = lo_existing_role->get_role( )->get_arn( ).
          CATCH /aws1/cx_iamnosuchentityex.
            " Could not find existing role, re-raise original exception
            RAISE EXCEPTION lo_entity_exists.
        ENDTRY.
      CATCH /aws1/cx_iamlimitexceededex INTO DATA(lo_limit_ex).
        MESSAGE 'IAM entity limit exceeded. Cannot create test resources.' TYPE 'I'.
        RAISE EXCEPTION TYPE /awsex/cx_generic
          EXPORTING
            textid = /awsex/cx_generic=>/awsex/cx_generic.
    ENDTRY.
  ENDMETHOD.

  METHOD class_teardown.
    " Clean up all resources created during testing
    " Resources are cleaned up in reverse order of dependencies
    TRY.
        " Step 1: Detach policy from role (if both exist)
        IF av_policy_arn IS NOT INITIAL AND av_role_name IS NOT INITIAL.
          TRY.
              ao_iam->detachrolepolicy(
                iv_rolename = av_role_name
                iv_policyarn = av_policy_arn
              ).
            CATCH /aws1/cx_iamnosuchentityex.
              " Policy or role may have already been deleted
          ENDTRY.
        ENDIF.

        " Step 2: Delete the policy
        IF av_policy_arn IS NOT INITIAL.
          TRY.
              ao_iam->deletepolicy( iv_policyarn = av_policy_arn ).
            CATCH /aws1/cx_iamnosuchentityex.
              " Policy may have already been deleted
          ENDTRY.
        ENDIF.

        " Step 3: Delete the role
        IF av_role_name IS NOT INITIAL.
          TRY.
              ao_iam->deleterole( iv_rolename = av_role_name ).
            CATCH /aws1/cx_iamnosuchentityex.
              " Role may have already been deleted
          ENDTRY.
        ENDIF.

      CATCH /aws1/cx_rt_generic INTO DATA(lo_generic_ex).
        " Log cleanup error but don't fail the test
        MESSAGE 'Error during cleanup. Resources may need manual deletion.' TYPE 'I'.
    ENDTRY.
  ENDMETHOD.

  METHOD assume_role.
    " Test AssumeRole without MFA
    " This demonstrates the basic AssumeRole functionality

    DATA lo_result TYPE REF TO /aws1/cl_stsassumeroleresponse.
    DATA lv_session_name TYPE /aws1/stsrolesessionnametype.

    lv_session_name = |abap-sts-test-session|.

    ao_sts_actions->assume_role(
      EXPORTING
        iv_role_arn = av_role_arn
        iv_role_session_name = lv_session_name
        iv_duration_seconds = 900    " 15 minutes
      IMPORTING
        oo_result = lo_result
    ).

    " Verify that we got temporary credentials
    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'AssumeRole did not return a result'
    ).

    DATA(lo_credentials) = lo_result->get_credentials( ).
    cl_abap_unit_assert=>assert_bound(
      act = lo_credentials
      msg = 'AssumeRole did not return credentials'
    ).

    " Verify that credentials have required fields
    DATA(lv_access_key_id) = lo_credentials->get_accesskeyid( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_access_key_id
      msg = 'Access key ID was not returned'
    ).

    DATA(lv_secret_access_key) = lo_credentials->get_secretaccesskey( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_secret_access_key
      msg = 'Secret access key was not returned'
    ).

    DATA(lv_session_token) = lo_credentials->get_sessiontoken( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_session_token
      msg = 'Session token was not returned'
    ).

    DATA(lv_expiration) = lo_credentials->get_expiration( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_expiration
      msg = 'Expiration was not returned'
    ).

    " Verify that the assumed role user information is present
    DATA(lo_assumed_role_user) = lo_result->get_assumedroleuser( ).
    cl_abap_unit_assert=>assert_bound(
      act = lo_assumed_role_user
      msg = 'AssumeRole did not return assumed role user information'
    ).

    DATA(lv_assumed_role_arn) = lo_assumed_role_user->get_arn( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_assumed_role_arn
      msg = 'Assumed role ARN was not returned'
    ).

  ENDMETHOD.

ENDCLASS.
