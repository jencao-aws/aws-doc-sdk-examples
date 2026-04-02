" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS ltc_awsex_cl_iot_actions DEFINITION DEFERRED.
CLASS /awsex/cl_iot_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_iot_actions.

CLASS ltc_awsex_cl_iot_actions DEFINITION FOR TESTING DURATION LONG RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_iot TYPE REF TO /aws1/if_iot.
    CLASS-DATA ao_iop TYPE REF TO /aws1/if_iop.
    CLASS-DATA ao_sns TYPE REF TO /aws1/if_sns.
    CLASS-DATA ao_iam TYPE REF TO /aws1/if_iam.
    CLASS-DATA ao_iot_actions TYPE REF TO /awsex/cl_iot_actions.

    CLASS-DATA av_thing_name TYPE /aws1/iotthingname.
    CLASS-DATA av_cert_id TYPE /aws1/iotcertificateid.
    CLASS-DATA av_cert_arn TYPE /aws1/iotcertificatearn.
    CLASS-DATA av_topic_rule_name TYPE /aws1/iotrulename.
    CLASS-DATA av_sns_topic_arn TYPE /aws1/iotsnstopicarn.
    CLASS-DATA av_role_arn TYPE /aws1/iotrolearn.
    CLASS-DATA av_role_name TYPE /aws1/iamrolenametype.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic.

    METHODS create_thing FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS list_things FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS create_keys_and_certificate FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS attach_thing_principal FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS describe_endpoint FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS list_certificates FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS detach_thing_principal FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS delete_certificate FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS create_topic_rule FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS list_topic_rules FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS search_index FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS update_indexing_configuration FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS delete_thing FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS delete_topic_rule FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS update_thing_shadow FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS get_thing_shadow FOR TESTING RAISING /aws1/cx_rt_generic.

ENDCLASS.

CLASS ltc_awsex_cl_iot_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    ao_iot = /aws1/cl_iot_factory=>create( ao_session ).
    ao_iop = /aws1/cl_iop_factory=>create( ao_session ).
    ao_sns = /aws1/cl_sns_factory=>create( ao_session ).
    ao_iam = /aws1/cl_iam_factory=>create( ao_session ).
    ao_iot_actions = NEW /awsex/cl_iot_actions( ).

    " Generate unique names for test resources using utils
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    av_thing_name = |sapabap-iot-thing-{ lv_uuid }|.
    av_topic_rule_name = |sapabap_iot_rule_{ lv_uuid }|.
    av_role_name = |sapabap-iot-role-{ lv_uuid }|.

    " Step 1: Create SNS topic - must be created and tagged
    TRY.
        DATA(lo_topic_result) = ao_sns->createtopic(
          iv_name = |sapabap-iot-topic-{ lv_uuid }|
        ).
        av_sns_topic_arn = lo_topic_result->get_topicarn( ).

        " Tag SNS topic with convert_test tag
        ao_sns->tagresource(
          iv_resourcearn = av_sns_topic_arn
          it_tags = VALUE /aws1/cl_snstag=>tt_taglist(
            ( NEW /aws1/cl_snstag( iv_key = 'convert_test' iv_value = 'true' ) )
          )
        ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_sns_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create SNS topic: { lo_sns_ex->get_text( ) }|
        ).
    ENDTRY.

    " Step 2: Create IAM role for IoT with comprehensive permissions
    DATA(lv_assume_role_policy) = '{"Version":"2012-10-17","Statement":[' &&
      '{"Effect":"Allow","Principal":{"Service":"iot.amazonaws.com"},' &&
      '"Action":"sts:AssumeRole"}]}'.

    TRY.
        " Create the IAM role with convert_test tag
        DATA(lo_role_result) = ao_iam->createrole(
          iv_rolename = av_role_name
          iv_assumerolepolicydocument = lv_assume_role_policy
          it_tags = VALUE /aws1/cl_iamtag=>tt_taglisttype(
            ( NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) )
          )
        ).
        av_role_arn = lo_role_result->get_role( )->get_arn( ).
      CATCH /aws1/cx_iamentityalrdyexistsex.
        " Role exists from previous run, retrieve it
        DATA(lo_get_role) = ao_iam->getrole( iv_rolename = av_role_name ).
        av_role_arn = lo_get_role->get_role( )->get_arn( ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_iam_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create IAM role: { lo_iam_ex->get_text( ) }|
        ).
    ENDTRY.

    " Step 3: Attach comprehensive policy with all required permissions
    DATA(lv_sns_arn) = av_sns_topic_arn.
    DATA(lv_policy_document) = '{"Version":"2012-10-17","Statement":[' &&
      '{"Effect":"Allow","Action":["sns:Publish","sns:Subscribe"],' &&
      '"Resource":"' && lv_sns_arn && '"},' &&
      '{"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream",' &&
      '"logs:PutLogEvents","logs:DescribeLogStreams"],"Resource":"*"},' &&
      '{"Effect":"Allow","Action":["iot:Publish"],"Resource":"*"}]}'.

    TRY.
        ao_iam->putrolepolicy(
          iv_rolename = av_role_name
          iv_policyname = 'IoTComprehensivePolicy'
          iv_policydocument = lv_policy_document
        ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_policy_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to attach policy to role: { lo_policy_ex->get_text( ) }|
        ).
    ENDTRY.

    " Wait for IAM role to propagate
    WAIT UP TO 15 SECONDS.

    " Step 4: Create base certificate for tests - must succeed
    TRY.
        DATA(lo_cert_result) = ao_iot->createkeysandcertificate( iv_setasactive = abap_true ).
        av_cert_id = lo_cert_result->get_certificateid( ).
        av_cert_arn = lo_cert_result->get_certificatearn( ).

        " Wait for certificate to be ready
        WAIT UP TO 3 SECONDS.
      CATCH /aws1/cx_rt_generic INTO DATA(lo_cert_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create base certificate: { lo_cert_ex->get_text( ) }|
        ).
    ENDTRY.

    " Step 5: Enable thing indexing for search functionality
    TRY.
        DATA(lo_thing_indexing_config) = NEW /aws1/cl_iotthingindexingconf(
          iv_thingindexingmode = 'REGISTRY'
        ).
        ao_iot->updateindexingconfiguration(
          io_thingindexingconfiguration = lo_thing_indexing_config
        ).
        " Wait for indexing to be enabled
        WAIT UP TO 10 SECONDS.
      CATCH /aws1/cx_rt_generic.
        " Indexing might already be enabled, continue
    ENDTRY.
  ENDMETHOD.

  METHOD class_teardown.
    " Clean up base certificate
    IF av_cert_id IS NOT INITIAL.
      TRY.
          ao_iot->updatecertificate(
            iv_certificateid = av_cert_id
            iv_newstatus = 'INACTIVE'
          ).
          ao_iot->deletecertificate( iv_certificateid = av_cert_id ).
        CATCH /aws1/cx_rt_generic.
          " Certificate might already be deleted
      ENDTRY.
    ENDIF.

    " Clean up SNS topic
    IF av_sns_topic_arn IS NOT INITIAL.
      TRY.
          ao_sns->deletetopic( iv_topicarn = av_sns_topic_arn ).
        CATCH /aws1/cx_rt_generic.
          " Topic might already be deleted
      ENDTRY.
    ENDIF.

    " Clean up IAM role
    IF av_role_name IS NOT INITIAL.
      TRY.
          " Delete inline policies first
          ao_iam->deleterolepolicy(
            iv_rolename = av_role_name
            iv_policyname = 'IoTComprehensivePolicy'
          ).
        CATCH /aws1/cx_rt_generic.
          " Policy might not exist
      ENDTRY.

      TRY.
          " Delete role
          ao_iam->deleterole( iv_rolename = av_role_name ).
        CATCH /aws1/cx_rt_generic.
          " Role might already be deleted
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD create_thing.
    DATA(lv_test_thing) = |{ av_thing_name }-create|.

    TRY.
        DATA(lo_result) = ao_iot_actions->create_thing( lv_test_thing ).

        cl_abap_unit_assert=>assert_bound(
          act = lo_result
          msg = 'Thing creation failed - result is not bound' ).

        cl_abap_unit_assert=>assert_equals(
          exp = lv_test_thing
          act = lo_result->get_thingname( )
          msg = 'Thing name does not match expected value' ).

        " Cleanup
        ao_iot->deletething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        " Cleanup on error
        TRY.
            ao_iot->deletething( iv_thingname = lv_test_thing ).
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        cl_abap_unit_assert=>fail(
          msg = |create_thing test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD list_things.
    " Create a test thing to ensure we have something to list
    DATA(lv_test_thing) = |{ av_thing_name }-list|.

    TRY.
        ao_iot->creatething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        " Thing exists, continue
      CATCH /aws1/cx_rt_generic INTO DATA(lo_create_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create test thing: { lo_create_ex->get_text( ) }|
        ).
    ENDTRY.

    TRY.
        DATA(lo_result) = ao_iot_actions->list_things( ).

        cl_abap_unit_assert=>assert_bound(
          act = lo_result
          msg = 'List things failed - result is not bound' ).

        DATA(lt_things) = lo_result->get_things( ).
        cl_abap_unit_assert=>assert_not_initial(
          act = lt_things
          msg = 'No things found in list' ).

        " Cleanup
        ao_iot->deletething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        " Cleanup on error
        TRY.
            ao_iot->deletething( iv_thingname = lv_test_thing ).
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        cl_abap_unit_assert=>fail(
          msg = |list_things test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD create_keys_and_certificate.
    DATA lv_new_cert_id TYPE /aws1/iotcertificateid.

    TRY.
        DATA(lo_result) = ao_iot_actions->create_keys_and_certificate( ).

        cl_abap_unit_assert=>assert_bound(
          act = lo_result
          msg = 'Certificate creation failed - result is not bound' ).

        lv_new_cert_id = lo_result->get_certificateid( ).
        cl_abap_unit_assert=>assert_not_initial(
          act = lv_new_cert_id
          msg = 'Certificate ID not returned' ).

        " Cleanup - delete the newly created certificate
        ao_iot->updatecertificate(
          iv_certificateid = lv_new_cert_id
          iv_newstatus = 'INACTIVE'
        ).
        ao_iot->deletecertificate( iv_certificateid = lv_new_cert_id ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        " Cleanup on error
        IF lv_new_cert_id IS NOT INITIAL.
          TRY.
              ao_iot->updatecertificate(
                iv_certificateid = lv_new_cert_id
                iv_newstatus = 'INACTIVE'
              ).
              ao_iot->deletecertificate( iv_certificateid = lv_new_cert_id ).
            CATCH /aws1/cx_rt_generic.
          ENDTRY.
        ENDIF.
        cl_abap_unit_assert=>fail(
          msg = |create_keys_and_certificate test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD attach_thing_principal.
    DATA(lv_test_thing) = |{ av_thing_name }-attach|.

    TRY.
        " Create thing for this test
        ao_iot->creatething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        " Thing exists, continue
      CATCH /aws1/cx_rt_generic INTO DATA(lo_create_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create thing for attach test: { lo_create_ex->get_text( ) }|
        ).
    ENDTRY.

    TRY.
        " Use base certificate from setup
        DATA(lo_result) = ao_iot_actions->attach_thing_principal(
          iv_thing_name = lv_test_thing
          iv_principal = av_cert_arn
        ).

        cl_abap_unit_assert=>assert_bound(
          act = lo_result
          msg = 'Attach thing principal failed - result is not bound' ).

        " Cleanup
        ao_iot->detachthingprincipal(
          iv_thingname = lv_test_thing
          iv_principal = av_cert_arn
        ).
        ao_iot->deletething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        " Cleanup on error
        TRY.
            ao_iot->detachthingprincipal(
              iv_thingname = lv_test_thing
              iv_principal = av_cert_arn
            ).
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        TRY.
            ao_iot->deletething( iv_thingname = lv_test_thing ).
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        cl_abap_unit_assert=>fail(
          msg = |attach_thing_principal test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD describe_endpoint.
    TRY.
        DATA(lv_endpoint) = ao_iot_actions->describe_endpoint( 'iot:Data-ATS' ).

        cl_abap_unit_assert=>assert_not_initial(
          act = lv_endpoint
          msg = 'Endpoint not returned' ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail(
          msg = |describe_endpoint test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD list_certificates.
    " Base certificate was created in setup
    TRY.
        DATA(lo_result) = ao_iot_actions->list_certificates( ).

        cl_abap_unit_assert=>assert_bound(
          act = lo_result
          msg = 'List certificates failed - result is not bound' ).

        DATA(lt_certificates) = lo_result->get_certificates( ).
        cl_abap_unit_assert=>assert_not_initial(
          act = lt_certificates
          msg = 'No certificates found' ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail(
          msg = |list_certificates test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD detach_thing_principal.
    DATA(lv_test_thing) = |{ av_thing_name }-detach|.

    TRY.
        " Create thing for this test
        ao_iot->creatething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        " Thing exists, continue
      CATCH /aws1/cx_rt_generic INTO DATA(lo_create_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create thing for detach test: { lo_create_ex->get_text( ) }|
        ).
    ENDTRY.

    TRY.
        " Attach the base certificate first
        ao_iot->attachthingprincipal(
          iv_thingname = lv_test_thing
          iv_principal = av_cert_arn
        ).

        " Now test detaching
        DATA(lo_result) = ao_iot_actions->detach_thing_principal(
          iv_thing_name = lv_test_thing
          iv_principal = av_cert_arn
        ).

        cl_abap_unit_assert=>assert_bound(
          act = lo_result
          msg = 'Detach thing principal failed - result is not bound' ).

        " Cleanup
        ao_iot->deletething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        " Cleanup on error
        TRY.
            ao_iot->deletething( iv_thingname = lv_test_thing ).
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        cl_abap_unit_assert=>fail(
          msg = |detach_thing_principal test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD delete_certificate.
    " Create a new certificate specifically for deletion test
    DATA lv_cert_id TYPE /aws1/iotcertificateid.

    TRY.
        DATA(lo_cert) = ao_iot->createkeysandcertificate( iv_setasactive = abap_true ).
        lv_cert_id = lo_cert->get_certificateid( ).

        " Wait for certificate to be ready
        WAIT UP TO 3 SECONDS.

        " Test deleting the certificate
        ao_iot_actions->delete_certificate( lv_cert_id ).

        " Verify certificate is deleted
        DATA(lv_deleted) = abap_false.
        TRY.
            ao_iot->describecertificate( iv_certificateid = lv_cert_id ).
          CATCH /aws1/cx_iotresourcenotfoundex.
            lv_deleted = abap_true.
        ENDTRY.

        cl_abap_unit_assert=>assert_true(
          act = lv_deleted
          msg = 'Certificate was not deleted' ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        " Cleanup on error
        IF lv_cert_id IS NOT INITIAL.
          TRY.
              ao_iot->updatecertificate(
                iv_certificateid = lv_cert_id
                iv_newstatus = 'INACTIVE'
              ).
              ao_iot->deletecertificate( iv_certificateid = lv_cert_id ).
            CATCH /aws1/cx_rt_generic.
          ENDTRY.
        ENDIF.
        cl_abap_unit_assert=>fail(
          msg = |delete_certificate test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD create_topic_rule.
    DATA(lv_test_rule) = |{ av_topic_rule_name }_cre|.

    TRY.
        ao_iot_actions->create_topic_rule(
          iv_rule_name = lv_test_rule
          iv_topic = 'test/topic'
          iv_sns_action_arn = av_sns_topic_arn
          iv_role_arn = av_role_arn
        ).

        " Verify rule was created
        DATA(lo_rule) = ao_iot->gettopicrule( iv_rulename = lv_test_rule ).
        cl_abap_unit_assert=>assert_bound(
          act = lo_rule
          msg = 'Topic rule was not created' ).

        " Cleanup
        ao_iot->deletetopicrule( iv_rulename = lv_test_rule ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        " Cleanup on error
        TRY.
            ao_iot->deletetopicrule( iv_rulename = lv_test_rule ).
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        cl_abap_unit_assert=>fail(
          msg = |create_topic_rule test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD list_topic_rules.
    " Create a test rule first
    DATA(lv_test_rule) = |{ av_topic_rule_name }_lst|.

    TRY.
        DATA(lt_actions) = VALUE /aws1/cl_iotaction=>tt_actionlist(
          ( NEW /aws1/cl_iotaction(
              io_sns = NEW /aws1/cl_iotsnsaction(
                iv_targetarn = av_sns_topic_arn
                iv_rolearn = av_role_arn
              )
            )
          )
        ).
        DATA(lo_payload) = NEW /aws1/cl_iottopicrulepayload(
          iv_sql = |SELECT * FROM 'test/topic'|
          it_actions = lt_actions
        ).
        ao_iot->createtopicrule(
          iv_rulename = lv_test_rule
          io_topicrulepayload = lo_payload
        ).
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        " Rule exists, continue
      CATCH /aws1/cx_rt_generic INTO DATA(lo_create_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create rule for list test: { lo_create_ex->get_text( ) }|
        ).
    ENDTRY.

    TRY.
        DATA(lo_result) = ao_iot_actions->list_topic_rules( ).

        cl_abap_unit_assert=>assert_bound(
          act = lo_result
          msg = 'List topic rules failed - result is not bound' ).

        DATA(lt_rules) = lo_result->get_rules( ).
        cl_abap_unit_assert=>assert_not_initial(
          act = lt_rules
          msg = 'No topic rules found' ).

        " Cleanup
        ao_iot->deletetopicrule( iv_rulename = lv_test_rule ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        " Cleanup on error
        TRY.
            ao_iot->deletetopicrule( iv_rulename = lv_test_rule ).
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        cl_abap_unit_assert=>fail(
          msg = |list_topic_rules test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD search_index.
    " Indexing was enabled in setup, create a test thing
    DATA(lv_test_thing) = |{ av_thing_name }-search|.

    TRY.
        ao_iot->creatething( iv_thingname = lv_test_thing ).
        " Wait for thing to be indexed
        WAIT UP TO 15 SECONDS.
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        " Thing exists, continue
      CATCH /aws1/cx_rt_generic INTO DATA(lo_create_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create thing for search test: { lo_create_ex->get_text( ) }|
        ).
    ENDTRY.

    TRY.
        " Search for things using wildcard
        DATA(lo_result) = ao_iot_actions->search_index( 'thingName:*' ).

        cl_abap_unit_assert=>assert_bound(
          act = lo_result
          msg = 'Search index failed - result is not bound' ).

        " Cleanup
        ao_iot->deletething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        " Cleanup on error
        TRY.
            ao_iot->deletething( iv_thingname = lv_test_thing ).
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        cl_abap_unit_assert=>fail(
          msg = |search_index test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD update_indexing_configuration.
    TRY.
        ao_iot_actions->update_indexing_configuration( ).

        " Verify indexing is enabled
        DATA(lo_config) = ao_iot->getindexingconfiguration( ).
        cl_abap_unit_assert=>assert_equals(
          exp = 'REGISTRY'
          act = lo_config->get_thingindexingconfiguration( )->get_thingindexingmode( )
          msg = 'Indexing configuration was not updated' ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail(
          msg = |update_indexing_configuration test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD delete_thing.
    " Create a thing specifically for deletion test
    DATA(lv_test_thing) = |{ av_thing_name }-delete|.

    TRY.
        ao_iot->creatething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        " Thing exists, continue
      CATCH /aws1/cx_rt_generic INTO DATA(lo_create_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create thing for delete test: { lo_create_ex->get_text( ) }|
        ).
    ENDTRY.

    TRY.
        ao_iot_actions->delete_thing( lv_test_thing ).

        " Verify thing is deleted
        DATA(lv_deleted) = abap_false.
        TRY.
            ao_iot->describething( iv_thingname = lv_test_thing ).
          CATCH /aws1/cx_iotresourcenotfoundex.
            lv_deleted = abap_true.
        ENDTRY.

        cl_abap_unit_assert=>assert_true(
          act = lv_deleted
          msg = 'Thing was not deleted' ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail(
          msg = |delete_thing test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD delete_topic_rule.
    " Create a rule specifically for deletion test
    DATA(lv_test_rule) = |{ av_topic_rule_name }_del|.

    TRY.
        DATA(lt_actions) = VALUE /aws1/cl_iotaction=>tt_actionlist(
          ( NEW /aws1/cl_iotaction(
              io_sns = NEW /aws1/cl_iotsnsaction(
                iv_targetarn = av_sns_topic_arn
                iv_rolearn = av_role_arn
              )
            )
          )
        ).
        DATA(lo_payload) = NEW /aws1/cl_iottopicrulepayload(
          iv_sql = |SELECT * FROM 'test/topic'|
          it_actions = lt_actions
        ).
        ao_iot->createtopicrule(
          iv_rulename = lv_test_rule
          io_topicrulepayload = lo_payload
        ).
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        " Rule exists, continue
      CATCH /aws1/cx_rt_generic INTO DATA(lo_create_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create rule for delete test: { lo_create_ex->get_text( ) }|
        ).
    ENDTRY.

    TRY.
        ao_iot_actions->delete_topic_rule( lv_test_rule ).

        " Verify rule is deleted
        DATA(lv_deleted) = abap_false.
        TRY.
            ao_iot->gettopicrule( iv_rulename = lv_test_rule ).
          CATCH /aws1/cx_iotresourcenotfoundex.
            lv_deleted = abap_true.
        ENDTRY.

        cl_abap_unit_assert=>assert_true(
          act = lv_deleted
          msg = 'Topic rule was not deleted' ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail(
          msg = |delete_topic_rule test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD update_thing_shadow.
    " Create a thing for shadow testing
    DATA(lv_test_thing) = |{ av_thing_name }-shadow|.

    TRY.
        ao_iot->creatething( iv_thingname = lv_test_thing ).
        " Wait for thing to be ready
        WAIT UP TO 5 SECONDS.
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        " Thing exists, continue
      CATCH /aws1/cx_rt_generic INTO DATA(lo_create_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create thing for shadow test: { lo_create_ex->get_text( ) }|
        ).
    ENDTRY.

    TRY.
        DATA(lv_shadow_state) = '{"state":{"desired":{"color":"red"}}}'.
        DATA(lo_result) = ao_iot_actions->update_thing_shadow(
          iv_thing_name = lv_test_thing
          iv_shadow_state = lv_shadow_state
        ).

        cl_abap_unit_assert=>assert_bound(
          act = lo_result
          msg = 'Update thing shadow failed - result is not bound' ).

        " Cleanup
        ao_iop->deletethingshadow( iv_thingname = lv_test_thing ).
        ao_iot->deletething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        " Cleanup on error
        TRY.
            ao_iop->deletethingshadow( iv_thingname = lv_test_thing ).
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        TRY.
            ao_iot->deletething( iv_thingname = lv_test_thing ).
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        cl_abap_unit_assert=>fail(
          msg = |update_thing_shadow test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD get_thing_shadow.
    " Create a thing and update its shadow first
    DATA(lv_test_thing) = |{ av_thing_name }-getshdw|.

    TRY.
        ao_iot->creatething( iv_thingname = lv_test_thing ).
        " Wait for thing to be ready
        WAIT UP TO 5 SECONDS.
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        " Thing exists, continue
      CATCH /aws1/cx_rt_generic INTO DATA(lo_create_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create thing for get shadow test: { lo_create_ex->get_text( ) }|
        ).
    ENDTRY.

    TRY.
        " Create shadow first
        DATA(lv_shadow_state) = '{"state":{"desired":{"color":"blue"}}}'.
        ao_iop->updatethingshadow(
          iv_thingname = lv_test_thing
          iv_payload = lv_shadow_state
        ).
        " Wait for shadow to be updated
        WAIT UP TO 3 SECONDS.

        " Now test getting the shadow
        DATA(lo_result) = ao_iot_actions->get_thing_shadow( lv_test_thing ).

        cl_abap_unit_assert=>assert_bound(
          act = lo_result
          msg = 'Get thing shadow failed - result is not bound' ).

        cl_abap_unit_assert=>assert_not_initial(
          act = lo_result->get_payload( )
          msg = 'Shadow payload is empty' ).

        " Cleanup
        ao_iop->deletethingshadow( iv_thingname = lv_test_thing ).
        ao_iot->deletething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        " Cleanup on error
        TRY.
            ao_iop->deletethingshadow( iv_thingname = lv_test_thing ).
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        TRY.
            ao_iot->deletething( iv_thingname = lv_test_thing ).
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        cl_abap_unit_assert=>fail(
          msg = |get_thing_shadow test failed: { lo_ex->get_text( ) }|
        ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
