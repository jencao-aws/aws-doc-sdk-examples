" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS /awsex/cl_iot_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " snippet-start:[iot.abapv1.create_thing]
    METHODS create_thing
      IMPORTING
        iv_thing_name        TYPE /aws1/iotthingname
      RETURNING
        VALUE(oo_result)     TYPE REF TO /aws1/cl_iotcreatethingrsp
      RAISING
        /aws1/cx_rt_generic.
    " snippet-end:[iot.abapv1.create_thing]

    " snippet-start:[iot.abapv1.list_things]
    METHODS list_things
      RETURNING
        VALUE(ot_things)     TYPE /aws1/cl_iotthingattribute=>tt_thingattributelist
      RAISING
        /aws1/cx_rt_generic.
    " snippet-end:[iot.abapv1.list_things]

    " snippet-start:[iot.abapv1.create_keys_and_certificate]
    METHODS create_keys_and_certificate
      RETURNING
        VALUE(oo_result)     TYPE REF TO /aws1/cl_iotcrekeysandcertrsp
      RAISING
        /aws1/cx_rt_generic.
    " snippet-end:[iot.abapv1.create_keys_and_certificate]

    " snippet-start:[iot.abapv1.attach_thing_principal]
    METHODS attach_thing_principal
      IMPORTING
        iv_thing_name        TYPE /aws1/iotthingname
        iv_principal         TYPE /aws1/iotprincipal
      RETURNING
        VALUE(oo_result)     TYPE REF TO /aws1/cl_iotattachthgprincrsp
      RAISING
        /aws1/cx_rt_generic.
    " snippet-end:[iot.abapv1.attach_thing_principal]

    " snippet-start:[iot.abapv1.describe_endpoint]
    METHODS describe_endpoint
      IMPORTING
        VALUE(iv_endpoint_type) TYPE /aws1/iotendpointtype DEFAULT 'iot:Data-ATS'
      RETURNING
        VALUE(ov_endpoint)      TYPE /aws1/iotendpointaddress
      RAISING
        /aws1/cx_rt_generic.
    " snippet-end:[iot.abapv1.describe_endpoint]

    " snippet-start:[iot.abapv1.list_certificates]
    METHODS list_certificates
      RETURNING
        VALUE(ot_certificates) TYPE /aws1/cl_iotcertificate=>tt_certificates
      RAISING
        /aws1/cx_rt_generic.
    " snippet-end:[iot.abapv1.list_certificates]

    " snippet-start:[iot.abapv1.detach_thing_principal]
    METHODS detach_thing_principal
      IMPORTING
        iv_thing_name        TYPE /aws1/iotthingname
        iv_principal         TYPE /aws1/iotprincipal
      RETURNING
        VALUE(oo_result)     TYPE REF TO /aws1/cl_iotdetachthgprincrsp
      RAISING
        /aws1/cx_rt_generic.
    " snippet-end:[iot.abapv1.detach_thing_principal]

    " snippet-start:[iot.abapv1.delete_certificate]
    METHODS delete_certificate
      IMPORTING
        iv_certificate_id    TYPE /aws1/iotcertificateid
      RAISING
        /aws1/cx_rt_generic.
    " snippet-end:[iot.abapv1.delete_certificate]

    " snippet-start:[iot.abapv1.create_topic_rule]
    METHODS create_topic_rule
      IMPORTING
        iv_rule_name         TYPE /aws1/iotrulename
        iv_topic             TYPE /aws1/iottopic
        iv_sns_action_arn    TYPE /aws1/iotsnstopicarn
        iv_role_arn          TYPE /aws1/iotawsarn
      RAISING
        /aws1/cx_rt_generic.
    " snippet-end:[iot.abapv1.create_topic_rule]

    " snippet-start:[iot.abapv1.list_topic_rules]
    METHODS list_topic_rules
      RETURNING
        VALUE(ot_rules)      TYPE /aws1/cl_iottopicrulelistitem=>tt_topicrulelst
      RAISING
        /aws1/cx_rt_generic.
    " snippet-end:[iot.abapv1.list_topic_rules]

    " snippet-start:[iot.abapv1.search_index]
    METHODS search_index
      IMPORTING
        iv_query             TYPE /aws1/iotquerystring
      RETURNING
        VALUE(ot_things)     TYPE /aws1/cl_iotthingdocument=>tt_thingdocumentlist
      RAISING
        /aws1/cx_rt_generic.
    " snippet-end:[iot.abapv1.search_index]

    " snippet-start:[iot.abapv1.update_indexing_configuration]
    METHODS update_indexing_configuration
      RAISING
        /aws1/cx_rt_generic.
    " snippet-end:[iot.abapv1.update_indexing_configuration]

    " snippet-start:[iot.abapv1.delete_thing]
    METHODS delete_thing
      IMPORTING
        iv_thing_name        TYPE /aws1/iotthingname
      RAISING
        /aws1/cx_rt_generic.
    " snippet-end:[iot.abapv1.delete_thing]

    " snippet-start:[iot.abapv1.delete_topic_rule]
    METHODS delete_topic_rule
      IMPORTING
        iv_rule_name         TYPE /aws1/iotrulename
      RAISING
        /aws1/cx_rt_generic.
    " snippet-end:[iot.abapv1.delete_topic_rule]

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /AWSEX/CL_IOT_ACTIONS IMPLEMENTATION.


  METHOD create_thing.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.create_thing]
    TRY.
        " Example thing name: 'MyTestThing'
        oo_result = lo_iot->creatething(
          iv_thingname = iv_thing_name ).
        MESSAGE 'Thing created successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        MESSAGE 'Thing already exists.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.create_thing]
  ENDMETHOD.


  METHOD list_things.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.list_things]
    TRY.
        DATA(lo_result) = lo_iot->listthings( ).
        ot_things = lo_result->get_things( ).
        MESSAGE |Retrieved { lines( ot_things ) } things.| TYPE 'I'.
      CATCH /aws1/cx_iotthrottlingex.
        MESSAGE 'Request throttled. Please try again later.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.list_things]
  ENDMETHOD.


  METHOD create_keys_and_certificate.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.create_keys_and_certificate]
    TRY.
        " Set certificate as active
        oo_result = lo_iot->createkeysandcertificate(
          iv_setasactive = abap_true ).
        MESSAGE 'Certificate created successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotthrottlingex.
        MESSAGE 'Request throttled. Please try again later.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.create_keys_and_certificate]
  ENDMETHOD.


  METHOD attach_thing_principal.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.attach_thing_principal]
    TRY.
        " Example principal: 'arn:aws:iot:us-west-2:123456789012:cert/abc123'
        oo_result = lo_iot->attachthingprincipal(
          iv_thingname = iv_thing_name
          iv_principal = iv_principal ).
        MESSAGE 'Principal attached successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotresourcenotfoundex.
        MESSAGE 'Thing or principal not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.attach_thing_principal]
  ENDMETHOD.


  METHOD describe_endpoint.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.describe_endpoint]
    TRY.
        " Default endpoint type: 'iot:Data-ATS'
        DATA(lo_result) = lo_iot->describeendpoint(
          iv_endpointtype = iv_endpoint_type ).
        ov_endpoint = lo_result->get_endpointaddress( ).
        MESSAGE 'Retrieved endpoint successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotthrottlingex.
        MESSAGE 'Request throttled. Please try again later.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.describe_endpoint]
  ENDMETHOD.


  METHOD list_certificates.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.list_certificates]
    TRY.
        DATA(lo_result) = lo_iot->listcertificates( ).
        ot_certificates = lo_result->get_certificates( ).
        MESSAGE |Retrieved { lines( ot_certificates ) } certificates.| TYPE 'I'.
      CATCH /aws1/cx_iotthrottlingex.
        MESSAGE 'Request throttled. Please try again later.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.list_certificates]
  ENDMETHOD.


  METHOD detach_thing_principal.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.detach_thing_principal]
    TRY.
        " Example principal: 'arn:aws:iot:us-west-2:123456789012:cert/abc123'
        oo_result = lo_iot->detachthingprincipal(
          iv_thingname = iv_thing_name
          iv_principal = iv_principal ).
        MESSAGE 'Principal detached successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotresourcenotfoundex.
        MESSAGE 'Thing or principal not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.detach_thing_principal]
  ENDMETHOD.


  METHOD delete_certificate.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.delete_certificate]
    TRY.
        " First, set certificate to INACTIVE status
        lo_iot->updatecertificate(
          iv_certificateid = iv_certificate_id
          iv_newstatus = 'INACTIVE' ).

        " Then delete the certificate
        " Example certificate ID: 'abc123def456'
        lo_iot->deletecertificate(
          iv_certificateid = iv_certificate_id ).
        MESSAGE 'Certificate deleted successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotresourcenotfoundex.
        MESSAGE 'Certificate not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.delete_certificate]
  ENDMETHOD.


  METHOD create_topic_rule.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.create_topic_rule]
    TRY.
        " Create SNS action
        DATA(lo_sns_action) = NEW /aws1/cl_iotsnsaction(
          iv_targetarn = iv_sns_action_arn
          iv_rolearn = iv_role_arn ).

        " Create actions list
        DATA lt_actions TYPE /aws1/cl_iotaction=>tt_actionlist.
        APPEND NEW /aws1/cl_iotaction( io_sns = lo_sns_action ) TO lt_actions.

        " Create topic rule payload
        " Example SQL: 'SELECT * FROM ''device/data'''
        DATA lv_sql TYPE /aws1/iotsql.
        lv_sql = |SELECT * FROM '{ iv_topic }'|.

        DATA(lo_payload) = NEW /aws1/cl_iottopicrulepayload(
          iv_sql = lv_sql
          it_actions = lt_actions ).

        " Example rule name: 'MyTopicRule'
        lo_iot->createtopicrule(
          iv_rulename = iv_rule_name
          io_topicrulepayload = lo_payload ).
        MESSAGE 'Topic rule created successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        MESSAGE 'Topic rule already exists.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.create_topic_rule]
  ENDMETHOD.


  METHOD list_topic_rules.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.list_topic_rules]
    TRY.
        DATA(lo_result) = lo_iot->listtopicrules( ).
        ot_rules = lo_result->get_rules( ).
        MESSAGE |Retrieved { lines( ot_rules ) } topic rules.| TYPE 'I'.
      CATCH /aws1/cx_iotinternalexception.
        MESSAGE 'Internal error occurred.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.list_topic_rules]
  ENDMETHOD.


  METHOD search_index.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.search_index]
    TRY.
        " Example query: 'thingName:MyDevice'
        DATA(lo_result) = lo_iot->searchindex(
          iv_querystring = iv_query ).
        ot_things = lo_result->get_things( ).
        MESSAGE |Found { lines( ot_things ) } things.| TYPE 'I'.
      CATCH /aws1/cx_iotthrottlingex.
        MESSAGE 'Request throttled. Please try again later.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.search_index]
  ENDMETHOD.


  METHOD update_indexing_configuration.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.update_indexing_configuration]
    TRY.
        " Enable thing indexing
        DATA(lo_thing_indexing) = NEW /aws1/cl_iotthingindexingconf(
          iv_thingindexingmode = 'REGISTRY' ).

        lo_iot->updateindexingconfiguration(
          io_thingindexingconf = lo_thing_indexing ).
        MESSAGE 'Indexing configuration updated successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotthrottlingex.
        MESSAGE 'Request throttled. Please try again later.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.update_indexing_configuration]
  ENDMETHOD.


  METHOD delete_thing.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.delete_thing]
    TRY.
        " Example thing name: 'MyTestThing'
        lo_iot->deletething(
          iv_thingname = iv_thing_name ).
        MESSAGE 'Thing deleted successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotresourcenotfoundex.
        MESSAGE 'Thing not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.delete_thing]
  ENDMETHOD.


  METHOD delete_topic_rule.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.delete_topic_rule]
    TRY.
        " Example rule name: 'MyTopicRule'
        lo_iot->deletetopicrule(
          iv_rulename = iv_rule_name ).
        MESSAGE 'Topic rule deleted successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotinternalexception.
        MESSAGE 'Internal error occurred.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.delete_topic_rule]
  ENDMETHOD.
ENDCLASS.
