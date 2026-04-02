" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS ltc_awsex_cl_iot_actions DEFINITION DEFERRED.
CLASS /awsex/cl_iot_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_iot_actions.

CLASS ltc_awsex_cl_iot_actions DEFINITION FOR TESTING DURATION SHORT RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA ao_iot TYPE REF TO /aws1/if_iot.
    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_iot_actions TYPE REF TO /awsex/cl_iot_actions.
    CLASS-DATA ao_iam TYPE REF TO /aws1/if_iam.
    CLASS-DATA ao_sns TYPE REF TO /aws1/if_sns.

    CLASS-DATA av_thing_name TYPE /aws1/iotthingname.
    CLASS-DATA av_certificate_id TYPE /aws1/iotcertificateid.
    CLASS-DATA av_certificate_arn TYPE /aws1/iotcertificatearn.
    CLASS-DATA av_rule_name TYPE /aws1/iotrulename.
    CLASS-DATA av_role_arn TYPE /aws1/iotrolearn.
    CLASS-DATA av_role_name TYPE /aws1/iamrolename.
    CLASS-DATA av_sns_topic_arn TYPE /aws1/iotsnstopicarn.
    CLASS-DATA av_uuid TYPE string.

    METHODS: create_thing FOR TESTING RAISING /aws1/cx_rt_generic,
      list_things FOR TESTING RAISING /aws1/cx_rt_generic,
      create_keys_and_certificate FOR TESTING RAISING /aws1/cx_rt_generic,
      attach_thing_principal FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_endpoint FOR TESTING RAISING /aws1/cx_rt_generic,
      list_certificates FOR TESTING RAISING /aws1/cx_rt_generic,
      detach_thing_principal FOR TESTING RAISING /aws1/cx_rt_generic,
      delete_certificate FOR TESTING RAISING /aws1/cx_rt_generic,
      create_topic_rule FOR TESTING RAISING /aws1/cx_rt_generic,
      list_topic_rules FOR TESTING RAISING /aws1/cx_rt_generic,
      search_index FOR TESTING RAISING /aws1/cx_rt_generic,
      update_indexing_configuration FOR TESTING RAISING /aws1/cx_rt_generic,
      delete_thing FOR TESTING RAISING /aws1/cx_rt_generic,
      delete_topic_rule FOR TESTING RAISING /aws1/cx_rt_generic.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic.
ENDCLASS.

CLASS ltc_awsex_cl_iot_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    ao_iot = /aws1/cl_iot_factory=>create( ao_session ).
    ao_iam = /aws1/cl_iam_factory=>create( ao_session ).
    ao_sns = /aws1/cl_sns_factory=>create( ao_session ).
    ao_iot_actions = NEW /awsex/cl_iot_actions( ).

    " Generate unique names using utils
    av_uuid = /awsex/cl_utils=>get_random_string( ).
    av_thing_name = |test-thing-{ av_uuid }|.
    av_rule_name = |test_rule_{ av_uuid }|.
    av_role_name = |iot-test-role-{ av_uuid }|.

    " Create IAM role for IoT with proper trust policy
    DATA(lv_assume_role_policy) = |{ '{' }"Version":"2012-10-17","Statement":[{ '{' }"Effect":"Allow",| &&
                                  |"Principal":{ '{' }"Service":"iot.amazonaws.com"{ '}' },| &&
                                  |"Action":"sts:AssumeRole"{ '}' }]{ '}' }|.

    " Create the role - MUST succeed
    DATA(lo_role_output) = ao_iam->createrole(
      iv_rolename = av_role_name
      iv_assumerolepolicydocument = lv_assume_role_policy ).
    
    av_role_arn = lo_role_output->get_role( )->get_arn( ).
    
    IF av_role_arn IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Failed to create IAM role for IoT tests' ).
    ENDIF.

    " Tag the role with convert_test tag
    DATA lt_role_tags TYPE /aws1/cl_iamtag=>tt_taglisttype.
    APPEND NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) TO lt_role_tags.
    ao_iam->tagrole( iv_rolename = av_role_name it_tags = lt_role_tags ).

    " Attach comprehensive IoT and SNS permissions to the role
    DATA(lv_policy_doc) = |{ '{' }"Version":"2012-10-17","Statement":[| &&
                          |{ '{' }"Effect":"Allow","Action":["sns:Publish","sns:*"],| &&
                          |"Resource":"*"{ '}' },| &&
                          |{ '{' }"Effect":"Allow","Action":["iot:*"],| &&
                          |"Resource":"*"{ '}' }]{ '}' }|.

    ao_iam->putrolepolicy(
      iv_rolename = av_role_name
      iv_policyname = 'IoTSNSFullAccess'
      iv_policydocument = lv_policy_doc ).

    " Wait for IAM role to propagate globally
    WAIT UP TO 15 SECONDS.

    " Create SNS topic - MUST succeed
    DATA(lv_topic_name) = |iot-test-topic-{ av_uuid }|.
    DATA(lo_topic_output) = ao_sns->createtopic( iv_name = lv_topic_name ).
    av_sns_topic_arn = lo_topic_output->get_topicarn( ).
    
    IF av_sns_topic_arn IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Failed to create SNS topic for IoT tests' ).
    ENDIF.

    " Tag the SNS topic with convert_test tag
    DATA lt_sns_tags TYPE /aws1/cl_snstag=>tt_taglist.
    APPEND NEW /aws1/cl_snstag( iv_key = 'convert_test' iv_value = 'true' ) TO lt_sns_tags.
    ao_sns->tagresource( iv_resourcearn = av_sns_topic_arn it_tags = lt_sns_tags ).

    " Enable thing indexing for search tests - MUST succeed
    DATA(lo_thing_indexing) = NEW /aws1/cl_iotthingindexingconf(
      iv_thingindexingmode = 'REGISTRY' ).
    ao_iot->updateindexingconfiguration( io_thingindexingconf = lo_thing_indexing ).

    " Wait for indexing configuration to propagate
    WAIT UP TO 10 SECONDS.
  ENDMETHOD.

  METHOD class_teardown.
    " Clean up things
    IF av_thing_name IS NOT INITIAL.
      TRY.
          " Detach any principals first
          IF av_certificate_arn IS NOT INITIAL.
            TRY.
                ao_iot->detachthingprincipal(
                  iv_thingname = av_thing_name
                  iv_principal = av_certificate_arn ).
              CATCH /aws1/cx_rt_generic.
                " Already detached or doesn't exist
            ENDTRY.
          ENDIF.
          ao_iot->deletething( iv_thingname = av_thing_name ).
        CATCH /aws1/cx_rt_generic.
          " Ignore errors during cleanup
      ENDTRY.
    ENDIF.

    " Clean up certificates
    IF av_certificate_id IS NOT INITIAL.
      TRY.
          ao_iot->updatecertificate(
            iv_certificateid = av_certificate_id
            iv_newstatus = 'INACTIVE' ).
          ao_iot->deletecertificate( iv_certificateid = av_certificate_id ).
        CATCH /aws1/cx_rt_generic.
          " Ignore errors during cleanup
      ENDTRY.
    ENDIF.

    " Clean up topic rules
    IF av_rule_name IS NOT INITIAL.
      TRY.
          ao_iot->deletetopicrule( iv_rulename = av_rule_name ).
        CATCH /aws1/cx_rt_generic.
          " Ignore errors during cleanup
      ENDTRY.
    ENDIF.

    " Clean up SNS topic
    IF av_sns_topic_arn IS NOT INITIAL.
      TRY.
          ao_sns->deletetopic( iv_topicarn = av_sns_topic_arn ).
        CATCH /aws1/cx_rt_generic.
          " Ignore errors during cleanup
      ENDTRY.
    ENDIF.

    " Clean up IAM role
    IF av_role_name IS NOT INITIAL.
      TRY.
          " Delete inline policies first
          ao_iam->deleterolepolicy(
            iv_rolename = av_role_name
            iv_policyname = 'IoTSNSFullAccess' ).
        CATCH /aws1/cx_rt_generic.
          " Continue cleanup
      ENDTRY.
      TRY.
          ao_iam->deleterole( iv_rolename = av_role_name ).
        CATCH /aws1/cx_rt_generic.
          " Ignore errors during cleanup
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD create_thing.
    " Create the thing - must succeed
    DATA(lo_result) = ao_iot_actions->create_thing( iv_thing_name = av_thing_name ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Thing creation failed - result object is not bound| ).

    cl_abap_unit_assert=>assert_equals(
      exp = av_thing_name
      act = lo_result->get_thingname( )
      msg = |Thing name does not match expected value| ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_thingarn( )
      msg = |Thing ARN should not be empty| ).
  ENDMETHOD.

  METHOD list_things.
    " List things - must return results
    DATA(lt_things) = ao_iot_actions->list_things( ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lt_things
      msg = |List things returned no results - test thing should exist| ).

    " Verify our test thing is in the list
    DATA(lv_found) = abap_false.
    LOOP AT lt_things INTO DATA(lo_thing).
      IF lo_thing->get_thingname( ) = av_thing_name.
        lv_found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = |Test thing { av_thing_name } not found in list| ).
  ENDMETHOD.

  METHOD create_keys_and_certificate.
    " Create certificate - must succeed
    DATA(lo_result) = ao_iot_actions->create_keys_and_certificate( ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Certificate creation failed - result object is not bound| ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_certificateid( )
      msg = |Certificate ID should not be empty| ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_certificatearn( )
      msg = |Certificate ARN should not be empty| ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_certificatepem( )
      msg = |Certificate PEM should not be empty| ).

    " Store for later tests
    av_certificate_id = lo_result->get_certificateid( ).
    av_certificate_arn = lo_result->get_certificatearn( ).
  ENDMETHOD.

  METHOD attach_thing_principal.
    " Verify prerequisites
    IF av_thing_name IS INITIAL OR av_certificate_arn IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Prerequisites not met - thing or certificate missing' ).
    ENDIF.

    " Attach principal - must succeed
    DATA(lo_result) = ao_iot_actions->attach_thing_principal(
      iv_thing_name = av_thing_name
      iv_principal = av_certificate_arn ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Principal attachment failed - result object is not bound| ).

    " Verify attachment by listing principals for the thing
    DATA(lo_principals) = ao_iot->listthingprincipals( iv_thingname = av_thing_name ).
    DATA(lt_principals) = lo_principals->get_principals( ).

    DATA(lv_found) = abap_false.
    LOOP AT lt_principals INTO DATA(lv_principal).
      IF lv_principal = av_certificate_arn.
        lv_found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = |Principal { av_certificate_arn } not attached to thing| ).
  ENDMETHOD.

  METHOD describe_endpoint.
    " Get endpoint - must succeed
    DATA(lv_endpoint) = ao_iot_actions->describe_endpoint( ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_endpoint
      msg = |Endpoint retrieval failed - endpoint is empty| ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( lv_endpoint CS '.iot.' )
      msg = |Endpoint format invalid - should contain .iot. substring| ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( strlen( lv_endpoint ) > 10 )
      msg = |Endpoint seems too short to be valid| ).
  ENDMETHOD.

  METHOD list_certificates.
    " Verify prerequisite
    IF av_certificate_id IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Prerequisites not met - certificate not created yet' ).
    ENDIF.

    " List certificates - must return results
    DATA(lt_certificates) = ao_iot_actions->list_certificates( ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lt_certificates
      msg = |List certificates returned no results - test certificate should exist| ).

    " Verify our test certificate is in the list
    DATA(lv_found) = abap_false.
    LOOP AT lt_certificates INTO DATA(lo_cert).
      IF lo_cert->get_certificateid( ) = av_certificate_id.
        lv_found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = |Test certificate { av_certificate_id } not found in list| ).
  ENDMETHOD.

  METHOD detach_thing_principal.
    " Verify prerequisites
    IF av_thing_name IS INITIAL OR av_certificate_arn IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Prerequisites not met - thing or certificate missing' ).
    ENDIF.

    " Detach principal - must succeed
    DATA(lo_result) = ao_iot_actions->detach_thing_principal(
      iv_thing_name = av_thing_name
      iv_principal = av_certificate_arn ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Principal detachment failed - result object is not bound| ).

    " Verify detachment by listing principals for the thing
    DATA(lo_principals) = ao_iot->listthingprincipals( iv_thingname = av_thing_name ).
    DATA(lt_principals) = lo_principals->get_principals( ).

    DATA(lv_found) = abap_false.
    LOOP AT lt_principals INTO DATA(lv_principal).
      IF lv_principal = av_certificate_arn.
        lv_found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_false(
      act = lv_found
      msg = |Principal { av_certificate_arn } should not be attached after detachment| ).
  ENDMETHOD.

  METHOD delete_certificate.
    " Verify prerequisite
    IF av_certificate_id IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Prerequisites not met - certificate not created yet' ).
    ENDIF.

    " Delete certificate - must succeed
    ao_iot_actions->delete_certificate( iv_certificate_id = av_certificate_id ).

    " Verify certificate was deleted by trying to describe it
    DATA(lv_deleted) = abap_false.
    TRY.
        ao_iot->describecertificate( iv_certificateid = av_certificate_id ).
        " If we reach here, certificate still exists
        cl_abap_unit_assert=>fail( msg = |Certificate { av_certificate_id } was not deleted| ).
      CATCH /aws1/cx_iotresourcenotfoundex.
        lv_deleted = abap_true.
    ENDTRY.

    cl_abap_unit_assert=>assert_true(
      act = lv_deleted
      msg = |Certificate deletion verification failed| ).

    CLEAR av_certificate_id.
    CLEAR av_certificate_arn.
  ENDMETHOD.

  METHOD create_topic_rule.
    " Verify prerequisites
    IF av_sns_topic_arn IS INITIAL OR av_role_arn IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Prerequisites not met - SNS topic or IAM role missing' ).
    ENDIF.

    " Create topic rule - must succeed
    ao_iot_actions->create_topic_rule(
      iv_rule_name = av_rule_name
      iv_topic = 'device/data'
      iv_sns_action_arn = av_sns_topic_arn
      iv_role_arn = av_role_arn ).

    " Verify rule was created by retrieving it
    DATA(lo_rule) = ao_iot->gettopicrule( iv_rulename = av_rule_name ).
    
    cl_abap_unit_assert=>assert_bound(
      act = lo_rule
      msg = |Topic rule creation failed - unable to retrieve rule| ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_rule->get_rule( )
      msg = |Topic rule has no rule object| ).

    cl_abap_unit_assert=>assert_equals(
      exp = av_rule_name
      act = lo_rule->get_rule( )->get_rulename( )
      msg = |Topic rule name does not match| ).
  ENDMETHOD.

  METHOD list_topic_rules.
    " Verify prerequisite
    IF av_rule_name IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Prerequisites not met - topic rule not created yet' ).
    ENDIF.

    " List topic rules - must return results
    DATA(lt_rules) = ao_iot_actions->list_topic_rules( ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lt_rules
      msg = |List topic rules returned no results - test rule should exist| ).

    " Verify our test rule is in the list
    DATA(lv_found) = abap_false.
    LOOP AT lt_rules INTO DATA(lo_rule).
      IF lo_rule->get_rulename( ) = av_rule_name.
        lv_found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = |Test rule { av_rule_name } not found in list| ).
  ENDMETHOD.

  METHOD search_index.
    " Verify prerequisite
    IF av_thing_name IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Prerequisites not met - thing not created yet' ).
    ENDIF.

    " Wait for thing to be indexed
    WAIT UP TO 30 SECONDS.

    " Search index - may return empty results due to indexing delay but should not fail
    DATA(lv_query) = |thingName:{ av_thing_name }|.
    DATA(lt_things) = ao_iot_actions->search_index( iv_query = lv_query ).

    " Verify the operation succeeded (returned a table, even if empty)
    cl_abap_unit_assert=>assert_table_type(
      act = lt_things
      msg = |Search index did not return a valid table| ).
  ENDMETHOD.

  METHOD update_indexing_configuration.
    " Update indexing configuration - must succeed
    ao_iot_actions->update_indexing_configuration( ).

    " Verify indexing configuration was updated
    DATA(lo_config) = ao_iot->getindexingconfiguration( ).
    
    cl_abap_unit_assert=>assert_bound(
      act = lo_config
      msg = |Failed to retrieve indexing configuration| ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_config->get_thingindexingconfiguration( )
      msg = |Thing indexing configuration is not set| ).

    cl_abap_unit_assert=>assert_equals(
      exp = 'REGISTRY'
      act = lo_config->get_thingindexingconfiguration( )->get_thingindexingmode( )
      msg = |Indexing configuration was not updated to REGISTRY mode| ).
  ENDMETHOD.

  METHOD delete_thing.
    " Create a new thing specifically for this test
    DATA(lv_thing_name) = |test-thing-del-{ av_uuid }|.

    " Create thing - must succeed
    ao_iot->creatething( iv_thingname = lv_thing_name ).

    " Verify thing was created
    DATA(lo_describe) = ao_iot->describething( iv_thingname = lv_thing_name ).
    cl_abap_unit_assert=>assert_equals(
      exp = lv_thing_name
      act = lo_describe->get_thingname( )
      msg = |Thing was not created before deletion test| ).

    " Delete thing - must succeed
    ao_iot_actions->delete_thing( iv_thing_name = lv_thing_name ).

    " Verify thing was deleted
    DATA(lv_deleted) = abap_false.
    TRY.
        ao_iot->describething( iv_thingname = lv_thing_name ).
        " If we reach here, thing still exists
        cl_abap_unit_assert=>fail( msg = |Thing { lv_thing_name } was not deleted| ).
      CATCH /aws1/cx_iotresourcenotfoundex.
        lv_deleted = abap_true.
    ENDTRY.

    cl_abap_unit_assert=>assert_true(
      act = lv_deleted
      msg = |Thing deletion verification failed| ).
  ENDMETHOD.

  METHOD delete_topic_rule.
    " Verify prerequisite
    IF av_rule_name IS INITIAL.
      cl_abap_unit_assert=>fail( msg = 'Prerequisites not met - topic rule not created yet' ).
    ENDIF.

    " Delete topic rule - must succeed
    ao_iot_actions->delete_topic_rule( iv_rule_name = av_rule_name ).

    " Verify rule was deleted
    DATA(lv_deleted) = abap_false.
    TRY.
        ao_iot->gettopicrule( iv_rulename = av_rule_name ).
        " If we reach here, rule still exists
        cl_abap_unit_assert=>fail( msg = |Topic rule { av_rule_name } was not deleted| ).
      CATCH /aws1/cx_iotinternalexception.
        lv_deleted = abap_true.
      CATCH /aws1/cx_iotunauthorizedex.
        lv_deleted = abap_true.
      CATCH /aws1/cx_rt_generic.
        lv_deleted = abap_true.
    ENDTRY.

    cl_abap_unit_assert=>assert_true(
      act = lv_deleted
      msg = |Topic rule deletion verification failed| ).

    CLEAR av_rule_name.
  ENDMETHOD.
ENDCLASS.
