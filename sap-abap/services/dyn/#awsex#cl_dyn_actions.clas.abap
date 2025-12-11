CLASS /awsex/cl_dyn_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.

    METHODS create_table
      IMPORTING
        VALUE(iv_table_name) TYPE /aws1/dyntablename
      RETURNING
        VALUE(oo_result)     TYPE REF TO /aws1/cl_dyncreatetableoutput
      RAISING
        /aws1/cx_rt_generic .
    METHODS describe_table
      IMPORTING
        VALUE(iv_table_name) TYPE /aws1/dyntablename
      RETURNING
        VALUE(oo_result)     TYPE REF TO /aws1/cl_dyndescrtableoutput
      RAISING
        /aws1/cx_rt_generic .
    METHODS delete_table
      IMPORTING
        VALUE(iv_table_name) TYPE /aws1/dyntablename
      RAISING
        /aws1/cx_rt_generic .
    METHODS list_tables
      RETURNING
        VALUE(oo_result) TYPE REF TO /aws1/cl_dynlisttablesoutput
      RAISING
        /aws1/cx_rt_generic .
    METHODS put_item
      IMPORTING
        VALUE(iv_table_name) TYPE /aws1/dyntablename
        VALUE(it_item)       TYPE /aws1/cl_dynattributevalue=>tt_putiteminputattributemap
      RAISING
        /aws1/cx_rt_generic .
    METHODS get_item
      IMPORTING
        VALUE(iv_table_name) TYPE /aws1/dyntablename
        !it_key              TYPE /aws1/cl_dynattributevalue=>tt_key
      RETURNING
        VALUE(oo_item)       TYPE REF TO /aws1/cl_dyngetitemoutput
      RAISING
        /aws1/cx_rt_generic .
    METHODS update_item
      IMPORTING
        VALUE(iv_table_name)        TYPE /aws1/dyntablename
        VALUE(it_item_key)          TYPE /aws1/cl_dynattributevalue=>tt_key
        VALUE(it_attribute_updates) TYPE /aws1/cl_dynattrvalueupdate=>tt_attributeupdates
      RETURNING
        VALUE(oo_output)            TYPE REF TO /aws1/cl_dynupdateitemoutput
      RAISING
        /aws1/cx_rt_generic .
    METHODS delete_item
      IMPORTING
        VALUE(iv_table_name) TYPE /aws1/dyntablename
        VALUE(it_key_input)  TYPE /aws1/cl_dynattributevalue=>tt_key
      RAISING
        /aws1/cx_rt_generic .
    METHODS query_table
      IMPORTING
        VALUE(iv_table_name) TYPE /aws1/dyntablename
        VALUE(iv_year)       TYPE numeric
      RETURNING
        VALUE(oo_result)     TYPE REF TO /aws1/cl_dynqueryoutput
      RAISING
        /aws1/cx_rt_generic .
    METHODS scan_items
      IMPORTING
        VALUE(iv_table_name)  TYPE /aws1/dyntablename
        !iv_rating            TYPE numeric
      RETURNING
        VALUE(oo_scan_result) TYPE REF TO /aws1/cl_dynscanoutput
      RAISING
        /aws1/cx_rt_generic .
    METHODS batch_write_items
      IMPORTING
        VALUE(iv_table_name) TYPE /aws1/dyntablename
        VALUE(it_items)      TYPE /aws1/cl_dynattributevalue=>tt_itemlist
      RETURNING
        VALUE(oo_result)     TYPE REF TO /aws1/cl_dynbatchwriteitemout
      RAISING
        /aws1/cx_rt_generic .
    METHODS batch_get_items
      IMPORTING
        VALUE(iv_table_name) TYPE /aws1/dyntablename
        VALUE(it_keys)       TYPE /aws1/cl_dynattributevalue=>tt_keylist
      RETURNING
        VALUE(oo_result)     TYPE REF TO /aws1/cl_dynbatchgetitemoutput
      RAISING
        /aws1/cx_rt_generic .
    METHODS execute_statement
      IMPORTING
        VALUE(iv_statement) TYPE /aws1/dynpartiqlstatement
        VALUE(it_parameters) TYPE /aws1/cl_dynattributevalue=>tt_preparedstatementparameters OPTIONAL
      RETURNING
        VALUE(oo_result)    TYPE REF TO /aws1/cl_dynexecutestmtoutput
      RAISING
        /aws1/cx_rt_generic .
    METHODS batch_execute_statement
      IMPORTING
        VALUE(it_statements) TYPE /aws1/cl_dynbatchstmtrequest=>tt_partiqlbatchrequest
      RETURNING
        VALUE(oo_result)     TYPE REF TO /aws1/cl_dynbtcexecutestmtout
      RAISING
        /aws1/cx_rt_generic .
ENDCLASS.



CLASS /AWSEX/CL_DYN_ACTIONS IMPLEMENTATION.


  METHOD create_table.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_dyn) = /aws1/cl_dyn_factory=>create( lo_session ).

    " snippet-start:[dyn.abapv1.create_table]
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

        " Adjust read/write capacities as desired.
        DATA(lo_dynprovthroughput)  = NEW /aws1/cl_dynprovthroughput(
          iv_readcapacityunits = 5
          iv_writecapacityunits = 5 ).
        oo_result = lo_dyn->createtable(
          it_keyschema = lt_keyschema
          iv_tablename = iv_table_name
          it_attributedefinitions = lt_attributedefinitions
          io_provisionedthroughput = lo_dynprovthroughput ).
        " Table creation can take some time. Wait till table exists before returning.
        lo_dyn->get_waiter( )->tableexists(
          iv_max_wait_time = 200
          iv_tablename     = iv_table_name ).
        MESSAGE 'DynamoDB Table' && iv_table_name && 'created.' TYPE 'I'.
        " This exception can happen if the table already exists.
      CATCH /aws1/cx_dynresourceinuseex INTO DATA(lo_resourceinuseex).
        DATA(lv_error) = |"{ lo_resourceinuseex->av_err_code }" - { lo_resourceinuseex->av_err_msg }|.
        MESSAGE lv_error TYPE 'E'.
    ENDTRY.
    " snippet-end:[dyn.abapv1.create_table]
  ENDMETHOD.


  METHOD delete_item.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_dyn) = /aws1/cl_dyn_factory=>create( lo_session ).

    " snippet-start:[dyn.abapv1.delete_item]
    TRY.
        DATA(lo_resp) = lo_dyn->deleteitem(
          iv_tablename                = iv_table_name
          it_key                      = it_key_input ).
        MESSAGE 'Deleted one item.' TYPE 'I'.
      CATCH /aws1/cx_dyncondalcheckfaile00.
        MESSAGE 'A condition specified in the operation could not be evaluated.' TYPE 'E'.
      CATCH /aws1/cx_dynresourcenotfoundex.
        MESSAGE 'The table or index does not exist' TYPE 'E'.
      CATCH /aws1/cx_dyntransactconflictex.
        MESSAGE 'Another transaction is using the item' TYPE 'E'.
    ENDTRY.
    " snippet-end:[dyn.abapv1.delete_item]

  ENDMETHOD.


  METHOD delete_table.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_dyn) = /aws1/cl_dyn_factory=>create( lo_session ).

    " snippet-start:[dyn.abapv1.delete_table]
    TRY.
        lo_dyn->deletetable( iv_tablename = iv_table_name ).
        " Wait till the table is actually deleted.
        lo_dyn->get_waiter( )->tablenotexists(
          iv_max_wait_time = 200
          iv_tablename     = iv_table_name ).
        MESSAGE 'Table ' && iv_table_name && ' deleted.' TYPE 'I'.
      CATCH /aws1/cx_dynresourcenotfoundex.
        MESSAGE 'The table ' && iv_table_name && ' does not exist' TYPE 'E'.
      CATCH /aws1/cx_dynresourceinuseex.
        MESSAGE 'The table cannot be deleted since it is in use' TYPE 'E'.
    ENDTRY.
    " snippet-end:[dyn.abapv1.delete_table]
  ENDMETHOD.


  METHOD describe_table.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_dyn) = /aws1/cl_dyn_factory=>create( lo_session ).

    " snippet-start:[dyn.abapv1.describe_table]
    TRY.
        oo_result = lo_dyn->describetable( iv_tablename = iv_table_name ).
        DATA(lv_tablename) = oo_result->get_table( )->ask_tablename( ).
        DATA(lv_tablearn) = oo_result->get_table( )->ask_tablearn( ).
        DATA(lv_tablestatus) = oo_result->get_table( )->ask_tablestatus( ).
        DATA(lv_itemcount) = oo_result->get_table( )->ask_itemcount( ).
        MESSAGE 'The table name is ' && lv_tablename
            && '. The table ARN is ' && lv_tablearn
            && '. The tablestatus is ' && lv_tablestatus
            && '. Item count is ' && lv_itemcount TYPE 'I'.
      CATCH /aws1/cx_dynresourcenotfoundex.
        MESSAGE 'The table ' && lv_tablename && ' does not exist' TYPE 'E'.
    ENDTRY.
    " snippet-end:[dyn.abapv1.describe_table]

  ENDMETHOD.


  METHOD get_item.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_dyn) = /aws1/cl_dyn_factory=>create( lo_session ).

    " snippet-start:[dyn.abapv1.get_item]
    TRY.
        oo_item = lo_dyn->getitem(
          iv_tablename                = iv_table_name
          it_key                      = it_key ).
        DATA(lt_attr) = oo_item->get_item( ).
        DATA(lo_title) = lt_attr[ key = 'title' ]-value.
        DATA(lo_year) = lt_attr[ key = 'year' ]-value.
        DATA(lo_rating) = lt_attr[ key = 'rating' ]-value.
        MESSAGE 'Movie name is: ' && lo_title->get_s( )
          && 'Movie year is: ' && lo_year->get_n( )
          && 'Moving rating is: ' && lo_rating->get_n( ) TYPE 'I'.
      CATCH /aws1/cx_dynresourcenotfoundex.
        MESSAGE 'The table or index does not exist' TYPE 'E'.
    ENDTRY.
    " snippet-end:[dyn.abapv1.get_item]

  ENDMETHOD.


  METHOD list_tables.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_dyn) = /aws1/cl_dyn_factory=>create( lo_session ).

    " snippet-start:[dyn.abapv1.list_tables]
    TRY.
        oo_result = lo_dyn->listtables( ).
        " You can loop over the oo_result to get table properties like this.
        LOOP AT oo_result->get_tablenames( ) INTO DATA(lo_table_name).
          DATA(lv_tablename) = lo_table_name->get_value( ).
        ENDLOOP.
        DATA(lv_tablecount) = lines( oo_result->get_tablenames( ) ).
        MESSAGE 'Found ' && lv_tablecount && ' tables' TYPE 'I'.
      CATCH /aws1/cx_rt_service_generic INTO DATA(lo_exception).
        DATA(lv_error) = |"{ lo_exception->av_err_code }" - { lo_exception->av_err_msg }|.
        MESSAGE lv_error TYPE 'E'.
    ENDTRY.
    " snippet-end:[dyn.abapv1.list_tables]

  ENDMETHOD.


  METHOD put_item.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_dyn) = /aws1/cl_dyn_factory=>create( lo_session ).

    " snippet-start:[dyn.abapv1.put_item]
    TRY.
        DATA(lo_resp) = lo_dyn->putitem(
          iv_tablename = iv_table_name
          it_item      = it_item ).
        MESSAGE '1 row inserted into DynamoDB Table' && iv_table_name TYPE 'I'.
      CATCH /aws1/cx_dyncondalcheckfaile00.
        MESSAGE 'A condition specified in the operation could not be evaluated.' TYPE 'E'.
      CATCH /aws1/cx_dynresourcenotfoundex.
        MESSAGE 'The table or index does not exist' TYPE 'E'.
      CATCH /aws1/cx_dyntransactconflictex.
        MESSAGE 'Another transaction is using the item' TYPE 'E'.
    ENDTRY.
    " snippet-end:[dyn.abapv1.put_item]

  ENDMETHOD.


  METHOD query_table.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_dyn) = /aws1/cl_dyn_factory=>create( lo_session ).

    " snippet-start:[dyn.abapv1.query_table]

    TRY.
        " Query movies for a given year .
        DATA(lt_attributelist) = VALUE /aws1/cl_dynattributevalue=>tt_attributevaluelist(
            ( NEW /aws1/cl_dynattributevalue( iv_n = |{ iv_year }| ) ) ).
        DATA(lt_key_conditions) = VALUE /aws1/cl_dyncondition=>tt_keyconditions(
          ( VALUE /aws1/cl_dyncondition=>ts_keyconditions_maprow(
          key = 'year'
          value = NEW /aws1/cl_dyncondition(
          it_attributevaluelist = lt_attributelist
          iv_comparisonoperator = |EQ|
          ) ) ) ).
        oo_result = lo_dyn->query(
          iv_tablename = iv_table_name
          it_keyconditions = lt_key_conditions ).
        DATA(lt_items) = oo_result->get_items( ).
        "You can loop over the results to get item attributes.
        LOOP AT lt_items INTO DATA(lt_item).
          DATA(lo_title) = lt_item[ key = 'title' ]-value.
          DATA(lo_year) = lt_item[ key = 'year' ]-value.
        ENDLOOP.
        DATA(lv_count) = oo_result->get_count( ).
        MESSAGE 'Item count is: ' && lv_count TYPE 'I'.
      CATCH /aws1/cx_dynresourcenotfoundex.
        MESSAGE 'The table or index does not exist' TYPE 'E'.
    ENDTRY.
    " snippet-end:[dyn.abapv1.query_table]

  ENDMETHOD.


  METHOD scan_items.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_dyn) = /aws1/cl_dyn_factory=>create( lo_session ).

    " snippet-start:[dyn.abapv1.scan_items]
    TRY.
        " Scan movies for rating greater than or equal to the rating specified
        DATA(lt_attributelist) = VALUE /aws1/cl_dynattributevalue=>tt_attributevaluelist(
            ( NEW /aws1/cl_dynattributevalue( iv_n = |{ iv_rating }| ) ) ).
        DATA(lt_filter_conditions) = VALUE /aws1/cl_dyncondition=>tt_filterconditionmap(
          ( VALUE /aws1/cl_dyncondition=>ts_filterconditionmap_maprow(
          key = 'rating'
          value = NEW /aws1/cl_dyncondition(
          it_attributevaluelist = lt_attributelist
          iv_comparisonoperator = |GE|
          ) ) ) ).
        oo_scan_result = lo_dyn->scan( iv_tablename = iv_table_name
          it_scanfilter = lt_filter_conditions ).
        DATA(lt_items) = oo_scan_result->get_items( ).
        LOOP AT lt_items INTO DATA(lo_item).
          " You can loop over to get individual attributes.
          DATA(lo_title) = lo_item[ key = 'title' ]-value.
          DATA(lo_year) = lo_item[ key = 'year' ]-value.
        ENDLOOP.
        DATA(lv_count) = oo_scan_result->get_count( ).
        MESSAGE 'Found ' && lv_count && ' items' TYPE 'I'.
      CATCH /aws1/cx_dynresourcenotfoundex.
        MESSAGE 'The table or index does not exist' TYPE 'E'.
    ENDTRY.
    " snippet-end:[dyn.abapv1.scan_items]

  ENDMETHOD.


  METHOD update_item.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_dyn) = /aws1/cl_dyn_factory=>create( lo_session ).

    " snippet-start:[dyn.abapv1.update_item]
    TRY.
        oo_output = lo_dyn->updateitem(
          iv_tablename        = iv_table_name
          it_key              = it_item_key
          it_attributeupdates = it_attribute_updates ).
        MESSAGE '1 item updated in DynamoDB Table' && iv_table_name TYPE 'I'.
      CATCH /aws1/cx_dyncondalcheckfaile00.
        MESSAGE 'A condition specified in the operation could not be evaluated.' TYPE 'E'.
      CATCH /aws1/cx_dynresourcenotfoundex.
        MESSAGE 'The table or index does not exist' TYPE 'E'.
      CATCH /aws1/cx_dyntransactconflictex.
        MESSAGE 'Another transaction is using the item' TYPE 'E'.
    ENDTRY.
    " snippet-end:[dyn.abapv1.update_item]

  ENDMETHOD.


  METHOD batch_write_items.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_dyn) = /aws1/cl_dyn_factory=>create( lo_session ).

    " snippet-start:[dyn.abapv1.batch_write_items]
    TRY.
        " Prepare write requests for batch operation
        DATA lt_write_requests TYPE /aws1/cl_dynwriterequest=>tt_writerequests.
        LOOP AT it_items INTO DATA(lo_item).
          DATA(lo_put_request) = NEW /aws1/cl_dynputrequest( it_item = lo_item ).
          DATA(lo_write_request) = NEW /aws1/cl_dynwriterequest( io_putrequest = lo_put_request ).
          APPEND lo_write_request TO lt_write_requests.
        ENDLOOP.

        " Create request items map
        DATA(lt_request_items) = VALUE /aws1/cl_dynwriterequest=>tt_batchwriteitemrequestmap(
          ( VALUE /aws1/cl_dynwriterequest=>ts_batchwriteitemreqmap_maprow(
              key = iv_table_name
              value = lt_write_requests ) ) ).

        " Execute batch write
        oo_result = lo_dyn->batchwriteitem(
          it_requestitems = lt_request_items ).

        DATA(lv_unprocessed) = lines( oo_result->get_unprocesseditems( ) ).
        IF lv_unprocessed > 0.
          MESSAGE |{ lv_unprocessed } items were unprocessed| TYPE 'I'.
        ELSE.
          MESSAGE 'All items written successfully to table' && iv_table_name TYPE 'I'.
        ENDIF.
      CATCH /aws1/cx_dynresourcenotfoundex.
        MESSAGE 'The table does not exist' TYPE 'E'.
      CATCH /aws1/cx_dynprovthruputexcdex.
        MESSAGE 'Provisioned throughput exceeded' TYPE 'E'.
    ENDTRY.
    " snippet-end:[dyn.abapv1.batch_write_items]
  ENDMETHOD.


  METHOD batch_get_items.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_dyn) = /aws1/cl_dyn_factory=>create( lo_session ).

    " snippet-start:[dyn.abapv1.batch_get_items]
    TRY.
        " Prepare keys and attributes structure for batch get
        DATA(lo_keys_and_attrs) = NEW /aws1/cl_dynkeysandattributes( it_keys = it_keys ).

        " Create request items map
        DATA(lt_request_items) = VALUE /aws1/cl_dynkeysandattributes=>tt_batchgetrequestmap(
          ( VALUE /aws1/cl_dynkeysandattributes=>ts_batchgetrequestmap_maprow(
              key = iv_table_name
              value = lo_keys_and_attrs ) ) ).

        " Execute batch get
        oo_result = lo_dyn->batchgetitem(
          it_requestitems = lt_request_items ).

        " Process responses
        DATA(lt_responses) = oo_result->get_responses( ).
        LOOP AT lt_responses ASSIGNING FIELD-SYMBOL(<response>).
          DATA(lv_item_count) = lines( <response>-value ).
          MESSAGE |Retrieved { lv_item_count } items from table { <response>-key }| TYPE 'I'.
        ENDLOOP.

        " Check for unprocessed keys
        DATA(lt_unprocessed) = oo_result->get_unprocessedkeys( ).
        IF lines( lt_unprocessed ) > 0.
          MESSAGE 'Some keys were unprocessed' TYPE 'I'.
        ENDIF.
      CATCH /aws1/cx_dynresourcenotfoundex.
        MESSAGE 'The table does not exist' TYPE 'E'.
      CATCH /aws1/cx_dynprovthruputexcdex.
        MESSAGE 'Provisioned throughput exceeded' TYPE 'E'.
    ENDTRY.
    " snippet-end:[dyn.abapv1.batch_get_items]
  ENDMETHOD.


  METHOD execute_statement.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_dyn) = /aws1/cl_dyn_factory=>create( lo_session ).

    " snippet-start:[dyn.abapv1.execute_statement]
    TRY.
        " Execute PartiQL statement
        oo_result = lo_dyn->executestatement(
          iv_statement = iv_statement
          it_parameters = it_parameters ).

        " Process results
        DATA(lt_items) = oo_result->get_items( ).
        DATA(lv_count) = lines( lt_items ).
        MESSAGE |PartiQL statement executed. { lv_count } items returned| TYPE 'I'.

      CATCH /aws1/cx_dynresourcenotfoundex.
        MESSAGE 'The table does not exist' TYPE 'E'.
      CATCH /aws1/cx_dyncondalcheckfaile00.
        MESSAGE 'A condition specified in the operation could not be evaluated' TYPE 'E'.
      CATCH /aws1/cx_dyntransactconflictex.
        MESSAGE 'Another transaction is using the item' TYPE 'E'.
    ENDTRY.
    " snippet-end:[dyn.abapv1.execute_statement]
  ENDMETHOD.


  METHOD batch_execute_statement.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_dyn) = /aws1/cl_dyn_factory=>create( lo_session ).

    " snippet-start:[dyn.abapv1.batch_execute_statement]
    TRY.
        " Execute batch of PartiQL statements
        oo_result = lo_dyn->batchexecutestatement(
          it_statements = it_statements ).

        " Process responses
        DATA(lt_responses) = oo_result->get_responses( ).
        DATA(lv_success_count) = 0.
        LOOP AT lt_responses INTO DATA(lo_response).
          IF lo_response->get_error( ) IS INITIAL.
            lv_success_count = lv_success_count + 1.
          ENDIF.
        ENDLOOP.

        MESSAGE |Batch executed: { lv_success_count } of { lines( lt_responses ) } statements successful| TYPE 'I'.

      CATCH /aws1/cx_dynresourcenotfoundex.
        MESSAGE 'The table does not exist' TYPE 'E'.
    ENDTRY.
    " snippet-end:[dyn.abapv1.batch_execute_statement]
  ENDMETHOD.
ENDCLASS.
