" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0

CLASS ltc_awsex_cl_dyn_actions DEFINITION DEFERRED.
CLASS /awsex/cl_dyn_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_dyn_actions.

CLASS ltc_awsex_cl_dyn_actions DEFINITION FOR TESTING
  DURATION LONG
  RISK LEVEL DANGEROUS.

  PROTECTED SECTION.
    METHODS: create_table FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_table FOR TESTING RAISING /aws1/cx_rt_generic,
      list_tables FOR TESTING RAISING /aws1/cx_rt_generic,
      put_item FOR TESTING RAISING /aws1/cx_rt_generic,
      get_item FOR TESTING RAISING /aws1/cx_rt_generic,
      query_table FOR TESTING RAISING /aws1/cx_rt_generic,
      scan_items FOR TESTING RAISING /aws1/cx_rt_generic,
      update_item FOR TESTING RAISING /aws1/cx_rt_generic,
      delete_item FOR TESTING RAISING /aws1/cx_rt_generic,
      delete_table FOR TESTING RAISING /aws1/cx_rt_generic,
      batch_write_items FOR TESTING RAISING /aws1/cx_rt_generic,
      batch_get_items FOR TESTING RAISING /aws1/cx_rt_generic,
      execute_statement FOR TESTING RAISING /aws1/cx_rt_generic,
      batch_execute_statement FOR TESTING RAISING /aws1/cx_rt_generic.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA ao_dyn TYPE REF TO /aws1/if_dyn.
    DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    DATA ao_dyn_actions TYPE REF TO /awsex/cl_dyn_actions.
    DATA av_table_name TYPE /aws1/dyntablename.

    METHODS setup RAISING /aws1/cx_rt_generic.
    METHODS teardown RAISING /aws1/cx_rt_generic.

    METHODS put_item_local
      IMPORTING iv_title  TYPE string
                iv_year   TYPE numeric
                iv_rating TYPE numeric
      RAISING   /aws1/cx_rt_generic.
    METHODS delete_table_local RAISING /aws1/cx_rt_generic.
    METHODS create_table_local RAISING /aws1/cx_rt_generic.
    METHODS assert_table_exists RAISING /aws1/cx_rt_generic.
    METHODS assert_table_notexists RAISING /aws1/cx_rt_generic.
    METHODS query_table_local
      IMPORTING iv_year         TYPE numeric
      RETURNING VALUE(ot_items) TYPE /aws1/cl_dynattributevalue=>tt_itemlist
      RAISING   /aws1/cx_rt_generic.

ENDCLASS.

CLASS ltc_awsex_cl_dyn_actions IMPLEMENTATION.

  METHOD setup.
    ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
    ao_dyn = /aws1/cl_dyn_factory=>create( ao_session ).
    ao_dyn_actions = NEW /awsex/cl_dyn_actions( ).
    av_table_name = |code-example-create-table|.
  ENDMETHOD.

  METHOD teardown.
    delete_table_local( ).
  ENDMETHOD.

  METHOD create_table.
    DATA(lo_table) = ao_dyn_actions->create_table( av_table_name ).
    assert_table_exists( ).
    MESSAGE 'create_table successful' TYPE 'I'.
  ENDMETHOD.

  METHOD describe_table.
    create_table_local( ).
    DATA(lo_table_description) = ao_dyn_actions->describe_table(
      av_table_name ).
    DATA(lv_returned_tablename) = lo_table_description->get_table( )->ask_tablename( ).
    cl_abap_unit_assert=>assert_equals(
            exp = av_table_name
            act = lv_returned_tablename
            msg = |Expected the table name to be { av_table_name } but found { lv_returned_tablename }| ).
    MESSAGE 'describe_table successful' TYPE 'I'.
  ENDMETHOD.

  METHOD list_tables.
    create_table_local( ).
    DATA(lo_tables) = ao_dyn_actions->list_tables( ).

    LOOP AT lo_tables->get_tablenames( ) INTO DATA(lo_table_name).
      IF lo_table_name->get_value( ) = av_table_name.
        DATA(lv_found) = abap_true.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = |List table is successful| ).
    MESSAGE 'list_tables successful' TYPE 'I'.
  ENDMETHOD.

  METHOD put_item.
    create_table_local( ).
    DATA(lt_item) = VALUE /aws1/cl_dynattributevalue=>tt_putiteminputattributemap(
      ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
       key = 'title' value = NEW /aws1/cl_dynattributevalue( iv_s = 'Jaws' ) ) )
      ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
       key = 'year' value = NEW /aws1/cl_dynattributevalue( iv_n = '1975' ) ) )
      ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
       key = 'rating' value = NEW /aws1/cl_dynattributevalue( iv_n = '7.8' ) ) ) ).
    ao_dyn_actions->put_item( iv_table_name = av_table_name
      it_item = lt_item ).
    DATA(lt_items) = query_table_local( '1975' ).
    READ TABLE lt_items INTO DATA(lt_attributes) INDEX 1.
    DATA(lo_rating) = lt_attributes[ key = 'rating' ]-value.
    DATA(lv_rating) = lo_rating->ask_n( ).
    cl_abap_unit_assert=>assert_equals( exp = |7.8|
       act = lv_rating
       msg = |Expected rating 7.5, found { lv_rating } | ).
    MESSAGE 'put_item successful' TYPE 'I'.
  ENDMETHOD.

  METHOD get_item.
    create_table_local( ).
    put_item_local( iv_title = 'Jaws'
      iv_year = 1975
      iv_rating = '7.5' ).
    DATA(lo_item) = ao_dyn_actions->get_item( iv_table_name = av_table_name
       it_key = VALUE /aws1/cl_dynattributevalue=>tt_key(
           ( VALUE /aws1/cl_dynattributevalue=>ts_key_maprow(
             key = 'title' value = NEW /aws1/cl_dynattributevalue( iv_s = 'Jaws' ) ) )
           ( VALUE /aws1/cl_dynattributevalue=>ts_key_maprow(
             key = 'year' value = NEW /aws1/cl_dynattributevalue( iv_n = '1975' ) ) )
           ) ).
    DATA(lt_attributes) = lo_item->get_item( ).
    DATA(lo_rating) = lt_attributes[ key = 'rating' ]-value.
    DATA(lv_rating) = lo_rating->ask_n( ).
    cl_abap_unit_assert=>assert_equals( exp = |7.5|
       act = lv_rating
       msg = |Expected rating 7.5, found { lv_rating } | ).
    MESSAGE 'get_item successful' TYPE 'I'.
  ENDMETHOD.

  METHOD query_table.
    create_table_local( ).
    put_item_local( iv_title = 'Jaws'
      iv_year = 1975
      iv_rating = '7.5' ).
    put_item_local( iv_title = 'Star Wars'
      iv_year = 1979
      iv_rating = '8.1' ).
    put_item_local( iv_title = 'Barbie'
      iv_year = 2023
      iv_rating = '7.9' ).
    DATA(lo_query_result) = ao_dyn_actions->query_table( iv_table_name = av_table_name
        iv_year = 1975 ).
    READ TABLE lo_query_result->get_items( ) INTO DATA(lt_item) INDEX 1.
    DATA(lo_title) = lt_item[ key = 'title' ]-value.
    DATA(lv_title) = lo_title->ask_s( ).
    cl_abap_unit_assert=>assert_equals( exp = |Jaws|
       act = lv_title
       msg = |Expected title Jaws, found { lv_title }| ).
    MESSAGE 'query_table successful' TYPE 'I'.
  ENDMETHOD.

  METHOD scan_items.
    create_table_local( ).
    put_item_local( iv_title = 'Jaws'
      iv_year = 1975
      iv_rating = '7.5' ).
    put_item_local( iv_title = 'Star Wars'
      iv_year = 1979
      iv_rating = '8.1' ).
    put_item_local( iv_title = 'Barbie'
      iv_year = 2023
      iv_rating = '7.8' ).
    " Scan table for rating higher than 7.8
    DATA(lo_scan_result) = ao_dyn_actions->scan_items( iv_table_name = av_table_name
      iv_rating = '7.8' ).
    DATA(lv_count) = lo_scan_result->get_count( ).
    cl_abap_unit_assert=>assert_equals( exp = |2|
       act = lv_count
       msg = |Expected count 3, found { |lv_count| }| ).
    MESSAGE 'scan_item successful' TYPE 'I'.
  ENDMETHOD.

  METHOD update_item.
    create_table_local( ).
    put_item_local( iv_title = 'Jaws'
      iv_year = 1975
      iv_rating = '7.5' ).
    put_item_local( iv_title = 'Star Wars'
      iv_year = 1979
      iv_rating = '8.1' ).
    DATA(lt_attributeupdates) = VALUE /aws1/cl_dynattrvalueupdate=>tt_attributeupdates(
      ( VALUE /aws1/cl_dynattrvalueupdate=>ts_attributeupdates_maprow(
      key = 'rating' value = NEW /aws1/cl_dynattrvalueupdate(
        io_value  = NEW /aws1/cl_dynattributevalue( iv_n = '7.6' )
        iv_action = |PUT| ) ) ) ).
    DATA(lt_key) = VALUE /aws1/cl_dynattributevalue=>tt_key(
      ( VALUE /aws1/cl_dynattributevalue=>ts_key_maprow(
       key = 'title' value = NEW /aws1/cl_dynattributevalue( iv_s = 'Jaws' ) ) )
      ( VALUE /aws1/cl_dynattributevalue=>ts_key_maprow(
       key = 'year' value = NEW /aws1/cl_dynattributevalue( iv_n = '1975' ) ) ) ).
    DATA(lo_resp) = ao_dyn_actions->update_item(
      iv_table_name        = av_table_name
      it_item_key              = lt_key
      it_attribute_updates = lt_attributeupdates ).
    " Use query item to verify that the update was successful.
    DATA(lt_attributelist) = VALUE /aws1/cl_dynattributevalue=>tt_attributevaluelist(
            ( NEW /aws1/cl_dynattributevalue( iv_n = '1975' ) ) ).
    DATA(lt_key_conditions) = VALUE /aws1/cl_dyncondition=>tt_keyconditions(
        ( VALUE /aws1/cl_dyncondition=>ts_keyconditions_maprow(
        key = 'year'
        value = NEW /aws1/cl_dyncondition(
          it_attributevaluelist = lt_attributelist
          iv_comparisonoperator = |EQ|
        ) ) ) ).
    DATA(lt_items) = query_table_local( 1975 ).
    READ TABLE lt_items INTO DATA(lt_item) INDEX 1.
    DATA(lo_rating) = lt_item[ key = 'rating' ]-value.
    DATA(lv_rating) = lo_rating->ask_n( ).
    cl_abap_unit_assert=>assert_equals( exp = |7.6|
       act = lv_rating
       msg = |Expected ratig 7.6, found { lv_rating }| ).
    MESSAGE 'update_item successful' TYPE 'I'.
  ENDMETHOD.

  METHOD delete_item.
    create_table_local( ).
    put_item_local( iv_title = 'Jaws'
      iv_year = 1975
      iv_rating = '7.5' ).
    put_item_local( iv_title = 'Star Wars'
      iv_year = 1975
      iv_rating = '8.1' ).
    DATA(lt_key) = VALUE /aws1/cl_dynattributevalue=>tt_key(
          ( VALUE /aws1/cl_dynattributevalue=>ts_key_maprow(
            key = 'title' value = NEW /aws1/cl_dynattributevalue( iv_s = 'Jaws' ) ) )
          ( VALUE /aws1/cl_dynattributevalue=>ts_key_maprow(
            key = 'year' value = NEW /aws1/cl_dynattributevalue( iv_n = '1975' ) ) ) ).
    ao_dyn_actions->delete_item( iv_table_name = av_table_name
      it_key_input = lt_key ).
    DATA(lt_items) = query_table_local( '1975' ).
    DATA(lv_count) = lines( lt_items ).
    cl_abap_unit_assert=>assert_equals( exp = |1|
       act = lv_count
       msg = |Expected count 1, found { |lv_count| }| ).
    MESSAGE 'delete_item successful' TYPE 'I'.
  ENDMETHOD.

  METHOD delete_table.
    create_table_local( ).
    ao_dyn_actions->delete_table( av_table_name ).
    assert_table_notexists( ).
    MESSAGE 'delete_table successful' TYPE 'I'.
  ENDMETHOD.

  METHOD assert_table_exists.
    DATA(lv_status) = ao_dyn->describetable( iv_tablename = av_table_name )->get_table( )->get_tablestatus( ).
    lv_status = ao_dyn->describetable( iv_tablename = av_table_name )->get_table( )->get_tablestatus( ).
    cl_abap_unit_assert=>assert_equals(
            exp = lv_status
            act = 'ACTIVE'
            msg = |Expected the table to be in 'ACTIVE' status but received { lv_status }| ).
  ENDMETHOD.

  METHOD assert_table_notexists.
    TRY.
        DATA(lv_status) = ao_dyn->describetable( iv_tablename = av_table_name )->get_table( )->get_tablestatus( ).
        /aws1/cl_rt_assert_abap=>assert_missed_exception( iv_exception = |/AWS1/CX_RT_SERVICE_GENERIC| ).
      CATCH /aws1/cx_rt_service_generic.
        "ignore. expected since the table does not exist
    ENDTRY.
  ENDMETHOD.

  METHOD delete_table_local.
    TRY.
        DATA(lo_resp) = ao_dyn->deletetable( av_table_name ).
        ao_dyn->get_waiter( )->tablenotexists(
          iv_max_wait_time = 200
          iv_tablename     = av_table_name ).
      CATCH /aws1/cx_dynresourcenotfoundex.
    ENDTRY.
  ENDMETHOD.

  METHOD put_item_local.
    DATA(lt_item) = VALUE /aws1/cl_dynattributevalue=>tt_putiteminputattributemap(
        ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
         key = 'title' value = NEW /aws1/cl_dynattributevalue( iv_s = iv_title ) ) )
        ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
         key = 'year' value = NEW /aws1/cl_dynattributevalue( iv_n = |{ iv_year }| ) ) )
        ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
         key = 'rating' value = NEW /aws1/cl_dynattributevalue( iv_n = |{ iv_rating }| ) ) ) ).
    ao_dyn->putitem( iv_tablename = av_table_name
      it_item = lt_item ).
  ENDMETHOD.

  METHOD create_table_local.
    TRY.
        DATA(lt_keyschema) = VALUE /aws1/cl_dynkeyschemaelement=>tt_keyschema(
          ( NEW /aws1/cl_dynkeyschemaelement( iv_attributename = 'year'
                                              iv_keytype = 'HASH' ) )
          ( NEW /aws1/cl_dynkeyschemaelement( iv_attributename = 'title'
                                              iv_keytype = 'RANGE' ) ) ).
        DATA(lt_attributedefinitions) = VALUE /aws1/cl_dynattributedefn=>tt_attributedefinitions(
          ( NEW /aws1/cl_dynattributedefn( iv_attributename = 'year'
                                           iv_attributetype = 'N' ) )
          ( NEW /aws1/cl_dynattributedefn( iv_attributename = 'title'
                                           iv_attributetype = 'S' ) ) ).

        " Tag the table for test resource tracking
        DATA(lt_tags) = VALUE /aws1/cl_dyntag=>tt_taglist(
          ( NEW /aws1/cl_dyntag( iv_key = 'convert_test'
                                  iv_value = 'true' ) ) ).

        " Adjust read/write capacities as desired.
        DATA(lo_dynprovthroughput)  = NEW /aws1/cl_dynprovthroughput(
          iv_readcapacityunits = 5
          iv_writecapacityunits = 5 ).
        ao_dyn->createtable(
          it_keyschema = lt_keyschema
          iv_tablename = av_table_name
          it_attributedefinitions = lt_attributedefinitions
          io_provisionedthroughput = lo_dynprovthroughput
          it_tags = lt_tags ).
        ao_dyn->get_waiter( )->tableexists(
          iv_max_wait_time = 200
          iv_tablename     = av_table_name ).
      CATCH /aws1/cx_rt_service_generic INTO DATA(lo_genericex).
        DATA(lv_error) = |"{ lo_genericex->av_err_code }" - { lo_genericex->av_err_msg }|.
        MESSAGE lv_error TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD query_table_local.
    TRY.
        DATA(lt_attributelist) = VALUE /aws1/cl_dynattributevalue=>tt_attributevaluelist(
            ( NEW /aws1/cl_dynattributevalue( iv_n = |{ iv_year }| ) ) ).
        DATA(lt_key_conditions) = VALUE /aws1/cl_dyncondition=>tt_keyconditions(
          ( VALUE /aws1/cl_dyncondition=>ts_keyconditions_maprow(
          key = 'year'
          value = NEW /aws1/cl_dyncondition(
          it_attributevaluelist = lt_attributelist
          iv_comparisonoperator = |EQ|
          ) ) ) ).
        DATA(lo_result) = ao_dyn->query(
          iv_tablename = av_table_name
          it_keyconditions = lt_key_conditions ).
        ot_items = lo_result->get_items( ).
      CATCH /aws1/cx_rt_service_generic INTO DATA(lo_genericex).
        DATA(lv_error) = |"{ lo_genericex->av_err_code }" - { lo_genericex->av_err_msg }|.
        MESSAGE lv_error TYPE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD batch_write_items.
    create_table_local( ).

    " Prepare multiple items for batch write
    DATA lt_items TYPE /aws1/cl_dynattributevalue=>tt_itemlist.

    " Item 1
    DATA(lt_item1) = VALUE /aws1/cl_dynattributevalue=>tt_putiteminputattributemap(
      ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
       key = 'title' value = NEW /aws1/cl_dynattributevalue( iv_s = 'The Matrix' ) ) )
      ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
       key = 'year' value = NEW /aws1/cl_dynattributevalue( iv_n = '1999' ) ) )
      ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
       key = 'rating' value = NEW /aws1/cl_dynattributevalue( iv_n = '8.7' ) ) ) ).
    APPEND lt_item1 TO lt_items.

    " Item 2
    DATA(lt_item2) = VALUE /aws1/cl_dynattributevalue=>tt_putiteminputattributemap(
      ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
       key = 'title' value = NEW /aws1/cl_dynattributevalue( iv_s = 'Inception' ) ) )
      ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
       key = 'year' value = NEW /aws1/cl_dynattributevalue( iv_n = '2010' ) ) )
      ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
       key = 'rating' value = NEW /aws1/cl_dynattributevalue( iv_n = '8.8' ) ) ) ).
    APPEND lt_item2 TO lt_items.

    " Item 3
    DATA(lt_item3) = VALUE /aws1/cl_dynattributevalue=>tt_putiteminputattributemap(
      ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
       key = 'title' value = NEW /aws1/cl_dynattributevalue( iv_s = 'Interstellar' ) ) )
      ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
       key = 'year' value = NEW /aws1/cl_dynattributevalue( iv_n = '2014' ) ) )
      ( VALUE /aws1/cl_dynattributevalue=>ts_putiteminputattrmap_maprow(
       key = 'rating' value = NEW /aws1/cl_dynattributevalue( iv_n = '8.6' ) ) ) ).
    APPEND lt_item3 TO lt_items.

    " Execute batch write
    DATA(lo_result) = ao_dyn_actions->batch_write_items(
      iv_table_name = av_table_name
      it_items = lt_items ).

    " Verify items were written by querying
    DATA(lt_items_1999) = query_table_local( 1999 ).
    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = lines( lt_items_1999 )
      msg = 'Expected 1 movie from 1999' ).

    DATA(lt_items_2010) = query_table_local( 2010 ).
    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = lines( lt_items_2010 )
      msg = 'Expected 1 movie from 2010' ).

    MESSAGE 'batch_write_items successful' TYPE 'I'.
  ENDMETHOD.


  METHOD batch_get_items.
    create_table_local( ).

    " First, add some test data
    put_item_local( iv_title = 'The Matrix'
                    iv_year = 1999
                    iv_rating = '8.7' ).
    put_item_local( iv_title = 'Inception'
                    iv_year = 2010
                    iv_rating = '8.8' ).
    put_item_local( iv_title = 'Interstellar'
                    iv_year = 2014
                    iv_rating = '8.6' ).

    " Prepare keys for batch get
    DATA lt_keys TYPE /aws1/cl_dynattributevalue=>tt_keylist.

    " Key 1
    DATA(lt_key1) = VALUE /aws1/cl_dynattributevalue=>tt_key(
      ( VALUE /aws1/cl_dynattributevalue=>ts_key_maprow(
       key = 'title' value = NEW /aws1/cl_dynattributevalue( iv_s = 'The Matrix' ) ) )
      ( VALUE /aws1/cl_dynattributevalue=>ts_key_maprow(
       key = 'year' value = NEW /aws1/cl_dynattributevalue( iv_n = '1999' ) ) ) ).
    APPEND lt_key1 TO lt_keys.

    " Key 2
    DATA(lt_key2) = VALUE /aws1/cl_dynattributevalue=>tt_key(
      ( VALUE /aws1/cl_dynattributevalue=>ts_key_maprow(
       key = 'title' value = NEW /aws1/cl_dynattributevalue( iv_s = 'Inception' ) ) )
      ( VALUE /aws1/cl_dynattributevalue=>ts_key_maprow(
       key = 'year' value = NEW /aws1/cl_dynattributevalue( iv_n = '2010' ) ) ) ).
    APPEND lt_key2 TO lt_keys.

    " Execute batch get
    DATA(lo_result) = ao_dyn_actions->batch_get_items(
      iv_table_name = av_table_name
      it_keys = lt_keys ).

    " Verify we got the items back
    DATA(lt_responses) = lo_result->get_responses( ).
    READ TABLE lt_responses ASSIGNING FIELD-SYMBOL(<response>) WITH KEY key = av_table_name.
    IF sy-subrc = 0.
      DATA(lv_count) = lines( <response>-value ).
      cl_abap_unit_assert=>assert_equals(
        exp = 2
        act = lv_count
        msg = |Expected 2 items, got { lv_count }| ).
    ELSE.
      cl_abap_unit_assert=>fail( msg = 'No response found for table' ).
    ENDIF.

    MESSAGE 'batch_get_items successful' TYPE 'I'.
  ENDMETHOD.


  METHOD execute_statement.
    create_table_local( ).

    " Use PartiQL to insert an item
    DATA(lv_insert_stmt) = |INSERT INTO "{ av_table_name }" VALUE \{'title':?,'year':?,'rating':?\}|.
    DATA(lt_params_insert) = VALUE /aws1/cl_dynattributevalue=>tt_preparedstatementparameters(
      ( NEW /aws1/cl_dynattributevalue( iv_s = 'The Dark Knight' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '2008' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '9.0' ) ) ).

    ao_dyn_actions->execute_statement(
      iv_statement = lv_insert_stmt
      it_parameters = lt_params_insert ).

    " Use PartiQL to select the item
    DATA(lv_select_stmt) = |SELECT * FROM "{ av_table_name }" WHERE title=? AND year=?|.
    DATA(lt_params_select) = VALUE /aws1/cl_dynattributevalue=>tt_preparedstatementparameters(
      ( NEW /aws1/cl_dynattributevalue( iv_s = 'The Dark Knight' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '2008' ) ) ).

    DATA(lo_result) = ao_dyn_actions->execute_statement(
      iv_statement = lv_select_stmt
      it_parameters = lt_params_select ).

    " Verify the item was retrieved
    DATA(lt_items) = lo_result->get_items( ).
    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = lines( lt_items )
      msg = 'Expected to retrieve 1 item' ).

    " Verify the rating
    READ TABLE lt_items INTO DATA(lt_item) INDEX 1.
    DATA(lo_rating) = lt_item[ key = 'rating' ]-value.
    cl_abap_unit_assert=>assert_equals(
      exp = '9.0'
      act = lo_rating->ask_n( )
      msg = 'Expected rating to be 9.0' ).

    " Use PartiQL to update the item
    DATA(lv_update_stmt) = |UPDATE "{ av_table_name }" SET rating=? WHERE title=? AND year=?|.
    DATA(lt_params_update) = VALUE /aws1/cl_dynattributevalue=>tt_preparedstatementparameters(
      ( NEW /aws1/cl_dynattributevalue( iv_n = '9.1' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_s = 'The Dark Knight' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '2008' ) ) ).

    ao_dyn_actions->execute_statement(
      iv_statement = lv_update_stmt
      it_parameters = lt_params_update ).

    " Use PartiQL to delete the item
    DATA(lv_delete_stmt) = |DELETE FROM "{ av_table_name }" WHERE title=? AND year=?|.
    DATA(lt_params_delete) = VALUE /aws1/cl_dynattributevalue=>tt_preparedstatementparameters(
      ( NEW /aws1/cl_dynattributevalue( iv_s = 'The Dark Knight' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '2008' ) ) ).

    ao_dyn_actions->execute_statement(
      iv_statement = lv_delete_stmt
      it_parameters = lt_params_delete ).

    MESSAGE 'execute_statement successful' TYPE 'I'.
  ENDMETHOD.


  METHOD batch_execute_statement.
    create_table_local( ).

    " Prepare batch of INSERT statements
    DATA lt_statements TYPE /aws1/cl_dynbatchstmtrequest=>tt_partiqlbatchrequest.

    " Statement 1
    DATA(lv_stmt1) = |INSERT INTO "{ av_table_name }" VALUE \{'title':?,'year':?,'rating':?\}|.
    DATA(lt_params1) = VALUE /aws1/cl_dynattributevalue=>tt_preparedstatementparameters(
      ( NEW /aws1/cl_dynattributevalue( iv_s = 'Pulp Fiction' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '1994' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '8.9' ) ) ).
    DATA(lo_stmt_req1) = NEW /aws1/cl_dynbatchstmtrequest(
      iv_statement = lv_stmt1
      it_parameters = lt_params1 ).
    APPEND lo_stmt_req1 TO lt_statements.

    " Statement 2
    DATA(lv_stmt2) = |INSERT INTO "{ av_table_name }" VALUE \{'title':?,'year':?,'rating':?\}|.
    DATA(lt_params2) = VALUE /aws1/cl_dynattributevalue=>tt_preparedstatementparameters(
      ( NEW /aws1/cl_dynattributevalue( iv_s = 'Fight Club' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '1999' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '8.8' ) ) ).
    DATA(lo_stmt_req2) = NEW /aws1/cl_dynbatchstmtrequest(
      iv_statement = lv_stmt2
      it_parameters = lt_params2 ).
    APPEND lo_stmt_req2 TO lt_statements.

    " Statement 3
    DATA(lv_stmt3) = |INSERT INTO "{ av_table_name }" VALUE \{'title':?,'year':?,'rating':?\}|.
    DATA(lt_params3) = VALUE /aws1/cl_dynattributevalue=>tt_preparedstatementparameters(
      ( NEW /aws1/cl_dynattributevalue( iv_s = 'Forrest Gump' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '1994' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '8.8' ) ) ).
    DATA(lo_stmt_req3) = NEW /aws1/cl_dynbatchstmtrequest(
      iv_statement = lv_stmt3
      it_parameters = lt_params3 ).
    APPEND lo_stmt_req3 TO lt_statements.

    " Execute batch insert
    DATA(lo_result) = ao_dyn_actions->batch_execute_statement(
      it_statements = lt_statements ).

    " Verify items were written
    DATA(lt_responses) = lo_result->get_responses( ).
    DATA(lv_success_count) = 0.
    LOOP AT lt_responses INTO DATA(lo_response).
      IF lo_response->get_error( ) IS INITIAL.
        lv_success_count = lv_success_count + 1.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_equals(
      exp = 3
      act = lv_success_count
      msg = |Expected 3 successful statements, got { lv_success_count }| ).

    " Now test batch SELECT
    CLEAR lt_statements.
    DATA(lv_select1) = |SELECT * FROM "{ av_table_name }" WHERE title=? AND year=?|.
    DATA(lt_sel_params1) = VALUE /aws1/cl_dynattributevalue=>tt_preparedstatementparameters(
      ( NEW /aws1/cl_dynattributevalue( iv_s = 'Pulp Fiction' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '1994' ) ) ).
    DATA(lo_sel_req1) = NEW /aws1/cl_dynbatchstmtrequest(
      iv_statement = lv_select1
      it_parameters = lt_sel_params1 ).
    APPEND lo_sel_req1 TO lt_statements.

    DATA(lv_select2) = |SELECT * FROM "{ av_table_name }" WHERE title=? AND year=?|.
    DATA(lt_sel_params2) = VALUE /aws1/cl_dynattributevalue=>tt_preparedstatementparameters(
      ( NEW /aws1/cl_dynattributevalue( iv_s = 'Fight Club' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '1999' ) ) ).
    DATA(lo_sel_req2) = NEW /aws1/cl_dynbatchstmtrequest(
      iv_statement = lv_select2
      it_parameters = lt_sel_params2 ).
    APPEND lo_sel_req2 TO lt_statements.

    lo_result = ao_dyn_actions->batch_execute_statement(
      it_statements = lt_statements ).

    lt_responses = lo_result->get_responses( ).
    cl_abap_unit_assert=>assert_equals(
      exp = 2
      act = lines( lt_responses )
      msg = 'Expected 2 responses from batch select' ).

    " Now test batch UPDATE
    CLEAR lt_statements.
    DATA(lv_update1) = |UPDATE "{ av_table_name }" SET rating=? WHERE title=? AND year=?|.
    DATA(lt_upd_params1) = VALUE /aws1/cl_dynattributevalue=>tt_preparedstatementparameters(
      ( NEW /aws1/cl_dynattributevalue( iv_n = '9.0' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_s = 'Pulp Fiction' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '1994' ) ) ).
    DATA(lo_upd_req1) = NEW /aws1/cl_dynbatchstmtrequest(
      iv_statement = lv_update1
      it_parameters = lt_upd_params1 ).
    APPEND lo_upd_req1 TO lt_statements.

    lo_result = ao_dyn_actions->batch_execute_statement(
      it_statements = lt_statements ).

    " Now test batch DELETE
    CLEAR lt_statements.
    DATA(lv_delete1) = |DELETE FROM "{ av_table_name }" WHERE title=? AND year=?|.
    DATA(lt_del_params1) = VALUE /aws1/cl_dynattributevalue=>tt_preparedstatementparameters(
      ( NEW /aws1/cl_dynattributevalue( iv_s = 'Pulp Fiction' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '1994' ) ) ).
    DATA(lo_del_req1) = NEW /aws1/cl_dynbatchstmtrequest(
      iv_statement = lv_delete1
      it_parameters = lt_del_params1 ).
    APPEND lo_del_req1 TO lt_statements.

    DATA(lv_delete2) = |DELETE FROM "{ av_table_name }" WHERE title=? AND year=?|.
    DATA(lt_del_params2) = VALUE /aws1/cl_dynattributevalue=>tt_preparedstatementparameters(
      ( NEW /aws1/cl_dynattributevalue( iv_s = 'Fight Club' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '1999' ) ) ).
    DATA(lo_del_req2) = NEW /aws1/cl_dynbatchstmtrequest(
      iv_statement = lv_delete2
      it_parameters = lt_del_params2 ).
    APPEND lo_del_req2 TO lt_statements.

    DATA(lv_delete3) = |DELETE FROM "{ av_table_name }" WHERE title=? AND year=?|.
    DATA(lt_del_params3) = VALUE /aws1/cl_dynattributevalue=>tt_preparedstatementparameters(
      ( NEW /aws1/cl_dynattributevalue( iv_s = 'Forrest Gump' ) )
      ( NEW /aws1/cl_dynattributevalue( iv_n = '1994' ) ) ).
    DATA(lo_del_req3) = NEW /aws1/cl_dynbatchstmtrequest(
      iv_statement = lv_delete3
      it_parameters = lt_del_params3 ).
    APPEND lo_del_req3 TO lt_statements.

    lo_result = ao_dyn_actions->batch_execute_statement(
      it_statements = lt_statements ).

    MESSAGE 'batch_execute_statement successful' TYPE 'I'.
  ENDMETHOD.
ENDCLASS.
