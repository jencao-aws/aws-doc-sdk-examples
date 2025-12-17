" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS /awsex/cl_frh_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " Put a single record to a Firehose delivery stream.
    METHODS put_record
      IMPORTING
        !iv_delivery_stream_name TYPE /aws1/frhdeliverystreamname
        !iv_data                 TYPE /aws1/frhdata
      RETURNING
        VALUE(oo_result)         TYPE REF TO /aws1/cl_frhputrecordoutput
      RAISING
        /aws1/cx_rt_generic .

    " Put a batch of records to a Firehose delivery stream.
    METHODS put_record_batch
      IMPORTING
        !iv_delivery_stream_name TYPE /aws1/frhdeliverystreamname
        !it_records              TYPE /aws1/cl_frhrecord=>tt_putrecordbatchreqentrylist
      RETURNING
        VALUE(oo_result)         TYPE REF TO /aws1/cl_frhputrecbatchoutput
      RAISING
        /aws1/cx_rt_generic .

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /awsex/cl_frh_actions IMPLEMENTATION.

  METHOD put_record.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_frh) = /aws1/cl_frh_factory=>create( lo_session ).

    " snippet-start:[frh.abapv1.put_record]
    TRY.
        oo_result = lo_frh->putrecord(
          iv_deliverystreamname = iv_delivery_stream_name
          io_record = NEW /aws1/cl_frhrecord( iv_data = iv_data )
        ).
        MESSAGE 'Record sent successfully.' TYPE 'I'.
      CATCH /aws1/cx_frhinvalidargumentex INTO DATA(lo_invalid_arg).
        MESSAGE lo_invalid_arg->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_frhinvkmsresourceex INTO DATA(lo_invalid_kms).
        MESSAGE lo_invalid_kms->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_frhinvalidsourceex INTO DATA(lo_invalid_source).
        MESSAGE lo_invalid_source->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_frhresourcenotfoundex INTO DATA(lo_notfound).
        MESSAGE lo_notfound->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_frhserviceunavailex INTO DATA(lo_unavailable).
        MESSAGE lo_unavailable->get_text( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[frh.abapv1.put_record]
  ENDMETHOD.

  METHOD put_record_batch.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_frh) = /aws1/cl_frh_factory=>create( lo_session ).

    " snippet-start:[frh.abapv1.put_record_batch]
    TRY.
        oo_result = lo_frh->putrecordbatch(
          iv_deliverystreamname = iv_delivery_stream_name
          it_records = it_records
        ).
        DATA(lv_failed_count) = oo_result->get_failedputcount( ).
        IF lv_failed_count > 0.
          MESSAGE |Failed to send { lv_failed_count } records in batch.| TYPE 'I'.
        ELSE.
          MESSAGE 'All records in batch sent successfully.' TYPE 'I'.
        ENDIF.
      CATCH /aws1/cx_frhinvalidargumentex INTO DATA(lo_invalid_arg).
        MESSAGE lo_invalid_arg->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_frhinvkmsresourceex INTO DATA(lo_invalid_kms).
        MESSAGE lo_invalid_kms->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_frhinvalidsourceex INTO DATA(lo_invalid_source).
        MESSAGE lo_invalid_source->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_frhresourcenotfoundex INTO DATA(lo_notfound).
        MESSAGE lo_notfound->get_text( ) TYPE 'E'.
      CATCH /aws1/cx_frhserviceunavailex INTO DATA(lo_unavailable).
        MESSAGE lo_unavailable->get_text( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[frh.abapv1.put_record_batch]
  ENDMETHOD.

ENDCLASS.
