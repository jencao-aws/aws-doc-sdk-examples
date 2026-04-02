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

    " Generate unique names for test resources
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    av_thing_name = |sapabap-test-thing-{ lv_uuid }|.
    av_topic_rule_name = |sapabap_test_rule_{ lv_uuid }|.

    " Create SNS topic for topic rule - must be created in setup
    TRY.
        DATA(lo_topic_result) = ao_sns->createtopic(
          iv_name = |sapabap-iot-test-topic-{ lv_uuid }|
        ).
        av_sns_topic_arn = lo_topic_result->get_topicarn( ).

        " Tag SNS topic for cleanup - must succeed
        ao_sns->tagresource(
          iv_resourcearn = av_sns_topic_arn
          it_tags = VALUE /aws1/cl_snstag=>tt_taglist(
            ( NEW /aws1/cl_snstag( iv_key = 'convert_test' iv_value = 'true' ) )
          )
        ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_sns_ex).
        " If SNS topic creation fails, fail the setup
        cl_abap_unit_assert=>fail(
          msg = |Failed to create SNS topic: { lo_sns_ex->get_text( ) }|
        ).
    ENDTRY.

    " Create IAM role for IoT topic rule - must be created in setup
    DATA(lv_assume_role_policy) = '{"Version":"2012-10-17","Statement":[' &&
      '{"Effect":"Allow","Principal":{"Service":"iot.amazonaws.com"},' &&
      '"Action":"sts:AssumeRole"}]}'.

    av_role_name = |sapabap-iot-test-role-{ lv_uuid }|.
    TRY.
        " Create the IAM role
        DATA(lo_role_result) = ao_iam->createrole(
          iv_rolename = av_role_name
          iv_assumerolepolicydocument = lv_assume_role_policy
          it_tags = VALUE /aws1/cl_iamtag=>tt_taglisttype(
            ( NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) )
          )
        ).
        av_role_arn = lo_role_result->get_role( )->get_arn( ).
      CATCH /aws1/cx_iamentityalrdyexex.
        " If role exists from previous run, get it and continue
        DATA(lo_get_role) = ao_iam->getrole( iv_rolename = av_role_name ).
        av_role_arn = lo_get_role->get_role( )->get_arn( ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_iam_ex).
        " If role creation fails, fail the setup
        cl_abap_unit_assert=>fail(
          msg = |Failed to create IAM role: { lo_iam_ex->get_text( ) }|
        ).
    ENDTRY.

    " Attach comprehensive policy to role - must include all necessary permissions
    DATA(lv_sns_arn) = av_sns_topic_arn.
    DATA(lv_policy_document) = '{"Version":"2012-10-17","Statement":[' &&
      '{"Effect":"Allow","Action":["sns:Publish"],"Resource":"' && lv_sns_arn && '"},' &&
      '{"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream",' &&
      '"logs:PutLogEvents"],"Resource":"*"},' &&
      '{"Effect":"Allow","Action":["iot:CreateTopicRule","iot:DeleteTopicRule",' &&
      '"iot:GetTopicRule","iot:ListTopicRules","iot:ReplaceTopicRule"],"Resource":"*"},' &&
      '{"Effect":"Allow","Action":["iam:PassRole"],"Resource":"*"}]}'.

    TRY.
        ao_iam->putrolepolicy(
          iv_rolename = av_role_name
          iv_policyname = 'IoTSNSPublish'
          iv_policydocument = lv_policy_document
        ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_policy_ex).
        " If policy attachment fails, fail the setup
        cl_abap_unit_assert=>fail(
          msg = |Failed to attach policy to role: { lo_policy_ex->get_text( ) }|
        ).
    ENDTRY.

    " Wait longer for IAM role and policies to propagate
    WAIT UP TO 20 SECONDS.

    " Create a base certificate for tests to use
    TRY.
        DATA(lo_cert_result) = ao_iot->createkeysandcertificate( iv_setasactive = abap_true ).
        av_cert_id = lo_cert_result->get_certificateid( ).
        av_cert_arn = lo_cert_result->get_certificatearn( ).

        " Wait for certificate to be ready
        WAIT UP TO 2 SECONDS.
      CATCH /aws1/cx_rt_generic INTO DATA(lo_cert_ex).
        " If certificate creation fails, fail the setup
        cl_abap_unit_assert=>fail(
          msg = |Failed to create base certificate: { lo_cert_ex->get_text( ) }|
        ).
    ENDTRY.

    " Enable thing indexing for search tests
    TRY.
        DATA(lo_thing_indexing_config) = NEW /aws1/cl_iotthingindexingconf(
          iv_thingindexingmode = 'REGISTRY'
        ).
        ao_iot->updateindexingconfiguration(
          io_thingindexingconf = lo_thing_indexing_config
        ).
        " Wait for indexing to be enabled
        WAIT UP TO 10 SECONDS.
      CATCH /aws1/cx_rt_generic.
        " Indexing might already be enabled, continue
    ENDTRY.
  ENDMETHOD.

  METHOD class_teardown.
    " Clean up thing if it exists
    IF av_thing_name IS NOT INITIAL.
      TRY.
          " First detach any principals
          DATA(lo_principals) = ao_iot->listthingprincipals( iv_thingname = av_thing_name ).
          LOOP AT lo_principals->get_principals( ) INTO DATA(lv_principal).
            TRY.
                ao_iot->detachthingprincipal(
                  iv_thingname = av_thing_name
                  iv_principal = lv_principal->get_value( )
                ).
              CATCH /aws1/cx_rt_generic.
                " Ignore detach errors
            ENDTRY.
          ENDLOOP.

          " Delete thing
          ao_iot->deletething( iv_thingname = av_thing_name ).
        CATCH /aws1/cx_rt_generic.
          " Thing might already be deleted
      ENDTRY.
    ENDIF.

    " Clean up certificate
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

    " Clean up topic rule
    IF av_topic_rule_name IS NOT INITIAL.
      TRY.
          ao_iot->deletetopicrule( iv_rulename = av_topic_rule_name ).
        CATCH /aws1/cx_rt_generic.
          " Rule might already be deleted
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
    IF av_role_arn IS NOT INITIAL.
      TRY.
          " Extract role name from ARN
          SPLIT av_role_arn AT '/' INTO TABLE DATA(lt_parts).
          DATA(lv_role_name) = lt_parts[ lines( lt_parts ) ].

          " Delete inline policies first
          TRY.
              ao_iam->deleterolepolicy(
                iv_rolename = lv_role_name
                iv_policyname = 'IoTSNSPublish'
              ).
            CATCH /aws1/cx_rt_generic.
          ENDTRY.

          " Delete role
          ao_iam->deleterole( iv_rolename = lv_role_name ).
        CATCH /aws1/cx_rt_generic.
          " Role might already be deleted
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD create_thing.
    DATA(lv_test_thing) = |{ av_thing_name }-create|.

    DATA(lo_result) = ao_iot_actions->create_thing( lv_test_thing ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Thing creation failed| ).

    cl_abap_unit_assert=>assert_equals(
      exp = lv_test_thing
      act = lo_result->get_thingname( )
      msg = |Thing name does not match| ).

    " Cleanup
    TRY.
        ao_iot->deletething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_rt_generic.
    ENDTRY.
  ENDMETHOD.

  METHOD list_things.
    " Create a test thing first
    DATA(lv_test_thing) = |{ av_thing_name }-list|.
    ao_iot->creatething( iv_thingname = lv_test_thing ).

    DATA(lo_result) = ao_iot_actions->list_things( ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |List things failed| ).

    DATA(lt_things) = lo_result->get_things( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_things
      msg = |No things found| ).

    " Cleanup
    TRY.
        ao_iot->deletething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_rt_generic.
    ENDTRY.
  ENDMETHOD.

  METHOD create_keys_and_certificate.
    DATA(lo_result) = ao_iot_actions->create_keys_and_certificate( ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Certificate creation failed| ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_certificateid( )
      msg = |Certificate ID not returned| ).

    " Clean up the newly created certificate
    TRY.
        DATA(lv_new_cert_id) = lo_result->get_certificateid( ).
        ao_iot->updatecertificate(
          iv_certificateid = lv_new_cert_id
          iv_newstatus = 'INACTIVE'
        ).
        ao_iot->deletecertificate( iv_certificateid = lv_new_cert_id ).
      CATCH /aws1/cx_rt_generic.
        " Ignore cleanup errors
    ENDTRY.
  ENDMETHOD.

  METHOD attach_thing_principal.
    " Create thing for this test
    DATA(lv_test_thing) = |{ av_thing_name }-attach|.
    
    TRY.
        ao_iot->creatething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        " Thing exists, continue
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create thing for attach test: { lo_ex->get_text( ) }|
        ).
    ENDTRY.

    " Use base certificate from setup
    DATA(lo_result) = ao_iot_actions->attach_thing_principal(
      iv_thing_name = lv_test_thing
      iv_principal = av_cert_arn
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Attach thing principal failed| ).

    " Cleanup
    TRY.
        ao_iot->detachthingprincipal(
          iv_thingname = lv_test_thing
          iv_principal = av_cert_arn
        ).
        ao_iot->deletething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_rt_generic.
        " Ignore cleanup errors
    ENDTRY.
  ENDMETHOD.

  METHOD describe_endpoint.
    DATA(lv_endpoint) = ao_iot_actions->describe_endpoint( 'iot:Data-ATS' ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_endpoint
      msg = |Endpoint not returned| ).
  ENDMETHOD.

  METHOD list_certificates.
    " Base certificate was created in setup, no need to create another
    DATA(lo_result) = ao_iot_actions->list_certificates( ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |List certificates failed| ).

    DATA(lt_certificates) = lo_result->get_certificates( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_certificates
      msg = |No certificates found| ).
  ENDMETHOD.

  METHOD detach_thing_principal.
    " Create thing and attach certificate from setup
    DATA(lv_test_thing) = |{ av_thing_name }-detach|.
    
    TRY.
        ao_iot->creatething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        " Thing exists, continue
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create thing for detach test: { lo_ex->get_text( ) }|
        ).
    ENDTRY.

    " Attach the base certificate
    TRY.
        ao_iot->attachthingprincipal(
          iv_thingname = lv_test_thing
          iv_principal = av_cert_arn
        ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_attach_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to attach principal: { lo_attach_ex->get_text( ) }|
        ).
    ENDTRY.

    " Now test detaching
    DATA(lo_result) = ao_iot_actions->detach_thing_principal(
      iv_thing_name = lv_test_thing
      iv_principal = av_cert_arn
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Detach thing principal failed| ).

    " Cleanup
    TRY.
        ao_iot->deletething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_rt_generic.
        " Ignore cleanup errors
    ENDTRY.
  ENDMETHOD.

  METHOD delete_certificate.
    " Create a new certificate for deletion
    DATA(lo_cert) = ao_iot->createkeysandcertificate( iv_setasactive = abap_true ).
    DATA(lv_cert_id) = lo_cert->get_certificateid( ).

    " Wait a moment for certificate to be available
    WAIT UP TO 2 SECONDS.

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
      msg = |Certificate was not deleted| ).
  ENDMETHOD.

  METHOD create_topic_rule.
    DATA(lv_test_rule) = |{ av_topic_rule_name }_create|.

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
      msg = |Topic rule was not created| ).

    " Cleanup
    TRY.
        ao_iot->deletetopicrule( iv_rulename = lv_test_rule ).
      CATCH /aws1/cx_rt_generic.
    ENDTRY.
  ENDMETHOD.

  METHOD list_topic_rules.
    " Create a test rule first
    DATA(lv_test_rule) = |{ av_topic_rule_name }_list|.
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

    DATA(lo_result) = ao_iot_actions->list_topic_rules( ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |List topic rules failed| ).

    DATA(lt_rules) = lo_result->get_rules( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_rules
      msg = |No topic rules found| ).

    " Cleanup
    TRY.
        ao_iot->deletetopicrule( iv_rulename = lv_test_rule ).
      CATCH /aws1/cx_rt_generic.
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
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        cl_abap_unit_assert=>fail(
          msg = |Failed to create thing for search test: { lo_ex->get_text( ) }|
        ).
    ENDTRY.

    " Search for things - use wildcard to ensure results
    DATA(lo_result) = ao_iot_actions->search_index( 'thingName:*' ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Search index failed| ).

    " Cleanup
    TRY.
        ao_iot->deletething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_rt_generic.
        " Ignore cleanup errors
    ENDTRY.
  ENDMETHOD.

  METHOD update_indexing_configuration.
    ao_iot_actions->update_indexing_configuration( ).

    " Verify indexing is enabled
    DATA(lo_config) = ao_iot->getindexingconfiguration( ).
    cl_abap_unit_assert=>assert_equals(
      exp = 'REGISTRY'
      act = lo_config->get_thingindexingconf( )->get_thingindexingmode( )
      msg = |Indexing configuration was not updated| ).
  ENDMETHOD.

  METHOD delete_thing.
    " Create a thing to delete
    DATA(lv_test_thing) = |{ av_thing_name }-delete|.
    ao_iot->creatething( iv_thingname = lv_test_thing ).

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
      msg = |Thing was not deleted| ).
  ENDMETHOD.

  METHOD delete_topic_rule.
    " Create a rule to delete
    DATA(lv_test_rule) = |{ av_topic_rule_name }_delete|.
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
      msg = |Topic rule was not deleted| ).
  ENDMETHOD.

  METHOD update_thing_shadow.
    " Create a thing first
    DATA(lv_test_thing) = |{ av_thing_name }-shadow|.
    TRY.
        ao_iot->creatething( iv_thingname = lv_test_thing ).
        " Wait for thing to be ready
        WAIT UP TO 5 SECONDS.
      CATCH /aws1/cx_iotresrcalrdyexistsex.
    ENDTRY.

    DATA(lv_shadow_state) = '{"state":{"desired":{"color":"red"}}}'.
    " Convert string to xstring for the API using codepage conversion
    DATA lv_shadow_xstring TYPE xstring.
    DATA(lo_conv) = cl_abap_conv_out_ce=>create( encoding = 'UTF-8' ).
    lo_conv->write( data = lv_shadow_state ).
    lv_shadow_xstring = lo_conv->get_buffer( ).
    
    DATA(lo_result) = ao_iot_actions->update_thing_shadow(
      iv_thing_name = lv_test_thing
      iv_shadow_state = lv_shadow_xstring
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Update thing shadow failed| ).

    " Cleanup
    TRY.
        ao_iop->deletethingshadow( iv_thingname = lv_test_thing ).
        ao_iot->deletething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_rt_generic.
    ENDTRY.
  ENDMETHOD.

  METHOD get_thing_shadow.
    " Create a thing and update its shadow first
    DATA(lv_test_thing) = |{ av_thing_name }-getshadow|.
    TRY.
        ao_iot->creatething( iv_thingname = lv_test_thing ).
        " Wait for thing to be ready
        WAIT UP TO 5 SECONDS.
      CATCH /aws1/cx_iotresrcalrdyexistsex.
    ENDTRY.

    DATA(lv_shadow_state) = '{"state":{"desired":{"color":"blue"}}}'.
    " Convert string to xstring for the API using codepage conversion
    DATA lv_shadow_xstring TYPE xstring.
    DATA(lo_conv) = cl_abap_conv_out_ce=>create( encoding = 'UTF-8' ).
    lo_conv->write( data = lv_shadow_state ).
    lv_shadow_xstring = lo_conv->get_buffer( ).
    
    TRY.
        ao_iop->updatethingshadow(
          iv_thingname = lv_test_thing
          iv_payload = lv_shadow_xstring
        ).
        " Wait for shadow to be updated
        WAIT UP TO 2 SECONDS.
      CATCH /aws1/cx_rt_generic.
    ENDTRY.

    DATA(lo_result) = ao_iot_actions->get_thing_shadow( lv_test_thing ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = |Get thing shadow failed| ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_payload( )
      msg = |Shadow payload is empty| ).

    " Cleanup
    TRY.
        ao_iop->deletethingshadow( iv_thingname = lv_test_thing ).
        ao_iot->deletething( iv_thingname = lv_test_thing ).
      CATCH /aws1/cx_rt_generic.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
