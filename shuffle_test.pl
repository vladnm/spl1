% shuffle_test.pl
% Ground-truth process for shuffle chaos-testing.
%
% This is a verbatim copy of the retail sales fulfillment process (sales.pl),
% registered under the isolated module process_library_shuffle_test so that
% the chaos harness can import it independently of the live sales model.
%
% The 42-step canonical sequence is the "answer key" that every shuffle trial
% is compared against.  Do not reorder or modify these steps; any change here
% changes what "correct" means for the harness.

:- module(process_library_shuffle_test, [
    process_metadata/2,
    process_goal/1,
    process_entity/2,
    process_entity_context/2,
    normalized_step/7,
    normalized_actions/1
]).

% ---------------------------------------------------------------------------
% Metadata
% ---------------------------------------------------------------------------

process_metadata(domain, shuffle_test).
process_metadata(session, shuffle_test).
process_metadata(title, 'Shuffle-test ground truth: retail sales fulfillment (copy of sales.pl)').

process_goal('Canonical 42-step sales sequence used as ground truth for shuffle chaos testing.').

% Structured goal contributed to process_model:process_goal/4 (multifile).
process_model:process_goal(shuffle_test, agent(customer), object(item_receipt), state('item_receipt:received')).

% Object sequence declarations — mirror of sales.pl.
% process_start_step: sr1 (transfer item) is the canonical first step.
% The priority topo sort gives score=10 to declared start steps when
% LastId=none, ensuring sr1 is always placed at position 1 regardless
% of the shuffled input order.
process_model:process_start_step(shuffle_test, sr1).

process_model:object_sequence(item_quote,          before, purchase_request,    business_convention(quote_before_order)).
process_model:object_sequence(item_quote,          before, shipping_options,    business_convention(quote_before_shipping)).
process_model:object_sequence(shipping_options,     before, shipping_address,    business_convention(options_before_address)).
process_model:object_sequence(shipping_options,     before, shipping_preferences,business_convention(options_before_preferences)).
process_model:object_sequence(purchase_request,     before, shipping_address,    business_convention(order_before_shipping_details)).
process_model:object_sequence(shipping_address,     before, shipping_preferences,business_convention(address_before_preferences)).
process_model:object_sequence(shipping_address,     before, credit_info,         business_convention(checkout_ux_flow)).
process_model:object_sequence(shipping_preferences, before, credit_info,         business_convention(checkout_ux_flow)).
process_model:object_sequence(credit_info,          before, item_payment,        goal_prerequisite(payment_authorisation)).
process_model:object_sequence(purchase_request,     before, item_payment,        goal_prerequisite(payment_authorisation)).
process_model:object_sequence(item_payment,         before, payment_transaction, temporal_bound(pay, within(1, hours))).
process_model:object_sequence(payment_transaction,  before, fulfillment_request, goal_prerequisite(fulfillment)).
process_model:object_sequence(purchase_request,     before, fulfillment_request, goal_prerequisite(fulfillment)).
% The physical item recurs in two lifecycle phases.  The early in-stock phase
% is modelled as a distinct `stock_item` identity (transferred, received); the
% late shipment phase keeps the `item` identity (sent_to_shipper .. delivered).
% Splitting the identity lets object_sequence disambiguate the two phases while
% leaving the delivery/receipt provenance (which keys off the `item` name)
% intact.
process_model:object_sequence(stock_item,           before, item_quote,          business_convention(stock_before_quote)).
process_model:object_sequence(fulfillment_request,  before, item,                goal_prerequisite(item_dispatch)).
process_model:object_sequence(item,                 before, item_delivery,       temporal_bound(deliver, within(1, hours))).
process_model:object_sequence(fulfillment_request,  before, item_delivery,       goal_prerequisite(receipt_generation)).
process_model:object_sequence(item_delivery,        before, item_receipt,        goal_prerequisite(receipt_generation)).

% Sub-goal declarations — mirror of sales.pl.
process_model:process_subgoal(shuffle_test, checkout_complete,   item_quote,           goal_prerequisite(purchase_request)).
process_model:process_subgoal(shuffle_test, checkout_complete,   shipping_options,     goal_prerequisite(purchase_request)).
process_model:process_subgoal_consumer(shuffle_test, checkout_complete,   purchase_request).
process_model:process_subgoal(shuffle_test, payment_authorisation, credit_info,        goal_prerequisite(item_payment)).
process_model:process_subgoal_consumer(shuffle_test, payment_authorisation, item_payment).
process_model:process_subgoal(shuffle_test, fulfillment,          payment_transaction, goal_prerequisite(fulfillment_request)).
process_model:process_subgoal_consumer(shuffle_test, fulfillment, fulfillment_request).
process_model:process_subgoal(shuffle_test, receipt_generation,   item_delivery,       goal_prerequisite(item_receipt)).
process_model:process_subgoal_consumer(shuffle_test, receipt_generation, item_receipt).

% ---------------------------------------------------------------------------
% Process-level sequencing constraints (4-arity with justification).
% Mirror of sales.pl — same step IDs, same justifications.
% ---------------------------------------------------------------------------

% --- A: Phase convergence ---
process_model:process_step_precedes(shuffle_test, sr5,  sr9,  location_convergence(retail_store_office, customer_device)).
process_model:process_step_precedes(shuffle_test, sr8,  sr9,  location_convergence(shipper_server_loc, customer_device)).
process_model:process_step_precedes(shuffle_test, sr14, sr11, location_convergence(customer_device, retail_store_office)).
process_model:process_step_precedes(shuffle_test, sr17, sr11, location_convergence(customer_device, retail_store_office)).
% --- A: Credit info -> approval ---
process_model:process_step_precedes(shuffle_test, sr11, sr23, goal_prerequisite(payment_authorisation)).
process_model:process_step_precedes(shuffle_test, sr20, sr26, goal_prerequisite(payment_authorisation)).
process_model:process_step_precedes(shuffle_test, sr22, sr26, location_convergence(retail_store_office, payment_gateway_server)).
process_model:process_step_precedes(shuffle_test, sr25, sr26, temporal_bound(approve, within(1, hours))).
% --- A: Approval -> payment and fulfillment ---
process_model:process_step_precedes(shuffle_test, sr26, sr29, temporal_bound(approve, within(24, hours))).
process_model:process_step_precedes(shuffle_test, sr26, sr32, goal_prerequisite(fulfillment)).
process_model:process_step_precedes(shuffle_test, sr29, sr30, temporal_bound(pay, within(1, hours))).
% --- A: Fulfillment and delivery ---
process_model:process_step_precedes(shuffle_test, sr31, sr34, location_convergence(retail_store_office, retail_store_warehouse)).
process_model:process_step_precedes(shuffle_test, sr33, sr34, location_convergence(retail_store_office, shipper_depot)).
process_model:process_step_precedes(shuffle_test, sr34, sr35, goal_prerequisite(item_dispatch)).
process_model:process_step_precedes(shuffle_test, sr35, sr36, location_convergence(retail_store_warehouse, shipper_depot)).
process_model:process_step_precedes(shuffle_test, sr36, sr37, temporal_bound(deliver, unbounded)).
process_model:process_step_precedes(shuffle_test, sr37, sr38, temporal_bound(deliver, within(1, hours))).
process_model:process_step_precedes(shuffle_test, sr38, sr39, location_convergence(shipper_depot, retail_store_office)).
process_model:process_step_precedes(shuffle_test, sr39, sr40, goal_prerequisite(receipt_generation)).
% --- B: Domain convention — sequential customer checkout sub-chains ---
process_model:process_step_precedes(shuffle_test, sr8,  sr12, business_convention(checkout_ux_flow)).
process_model:process_step_precedes(shuffle_test, sr14, sr15, business_convention(checkout_ux_flow)).
process_model:process_step_precedes(shuffle_test, sr17, sr18, business_convention(checkout_ux_flow)).
% --- C: Goal terminal chain ---
process_model:process_step_precedes(shuffle_test, sr40, sr41).
process_model:process_step_precedes(shuffle_test, sr41, sr42).

% ---------------------------------------------------------------------------
% Entity ontology (copied from sales.pl)
% ---------------------------------------------------------------------------

process_entity(external_agent,       unspecified_agent).
process_entity(customer,             individual_person).
process_entity(retail_store,         organization).
process_entity(shipper,              organization).
process_entity(payment_gateway,      system_component).
process_entity(sales_system,         system_component).
process_entity(shipper_server,       system_component).
process_entity(customer_email,       system_component).
process_entity(web_browser,          system_component).
process_entity(item,                 artifact).
process_entity(stock_item,           artifact).
process_entity(item_quote,           artifact).
process_entity(shipping_options,     artifact).
process_entity(purchase_request,     artifact).
process_entity(shipping_address,     artifact).
process_entity(shipping_preferences, artifact).
process_entity(credit_info,          artifact).
process_entity(item_payment,         artifact).
process_entity(payment_transaction,  artifact).
process_entity(fulfillment_request,  artifact).
process_entity(item_delivery,        artifact).
process_entity(item_receipt,         artifact).

process_entity_context(item,                 physical).
process_entity_context(item_quote,           informational).
process_entity_context(shipping_options,     informational).
process_entity_context(purchase_request,     informational).
process_entity_context(shipping_address,     informational).
process_entity_context(shipping_preferences, informational).
process_entity_context(credit_info,          informational).
process_entity_context(item_payment,         informational).
process_entity_context(payment_transaction,  informational).
process_entity_context(fulfillment_request,  informational).
process_entity_context(item_delivery,        informational).
process_entity_context(item_receipt,         informational).

% ---------------------------------------------------------------------------
% Canonical normalized sequence — the answer key (42 steps)
% These facts must remain in the correct causal order.
% ---------------------------------------------------------------------------

normalized_step(sr1,  transfer, external_agent,  system,          stock_item,           at(retail_store,    retail_store_warehouse),  'stock_item:transferred').
normalized_step(sr2,  receive,  retail_store,    retail_store,    stock_item,           at(external_agent,  shipper_depot),           'stock_item:received').
normalized_step(sr3,  generate, retail_store,    sales_system,    item_quote,           at(item,            retail_store_office),      'item_quote:generated').
normalized_step(sr4,  send,     retail_store,    sales_system,    item_quote,           at(customer,        customer_device),          'item_quote:sent').
normalized_step(sr5,  receive,  customer,        web_browser,     item_quote,           at(retail_store,    retail_store_office),      'item_quote:received').
normalized_step(sr6,  generate, shipper,         shipper_server,  shipping_options,     at(customer,        customer_device),          'shipping_options:generated').
normalized_step(sr7,  send,     shipper,         shipper_server,  shipping_options,     at(customer,        customer_device),          'shipping_options:sent').
normalized_step(sr8,  receive,  customer,        web_browser,     shipping_options,     at(shipper,         shipper_server_loc),       'shipping_options:received').
normalized_step(sr9,  generate, customer,        web_browser,     purchase_request,     at(item_quote,      customer_device),          'purchase_request:generated').
normalized_step(sr10, send,     customer,        web_browser,     purchase_request,     at(retail_store,    retail_store_office),      'purchase_request:sent').
normalized_step(sr11, receive,  retail_store,    sales_system,    purchase_request,     at(customer,        customer_device),          'purchase_request:received').
normalized_step(sr12, generate, customer,        web_browser,     shipping_address,     at(customer,        customer_device),          'shipping_address:generated').
normalized_step(sr13, send,     customer,        web_browser,     shipping_address,     at(shipper,         shipper_server_loc),       'shipping_address:sent').
normalized_step(sr14, receive,  shipper,         shipper_server,  shipping_address,     at(customer,        customer_device),          'shipping_address:received').
normalized_step(sr15, generate, customer,        web_browser,     shipping_preferences, at(customer,        customer_device),          'shipping_preferences:generated').
normalized_step(sr16, send,     customer,        web_browser,     shipping_preferences, at(shipper,         shipper_server_loc),       'shipping_preferences:sent').
normalized_step(sr17, receive,  shipper,         shipper_server,  shipping_preferences, at(customer,        customer_device),          'shipping_preferences:received').
normalized_step(sr18, generate, customer,        web_browser,     credit_info,          at(customer,        customer_device),          'credit_info:generated').
normalized_step(sr19, send,     customer,        web_browser,     credit_info,          at(retail_store,    retail_store_office),      'credit_info:sent').
normalized_step(sr20, receive,  retail_store,    sales_system,    credit_info,          at(customer,        customer_device),          'credit_info:received').
normalized_step(sr21, send,     retail_store,    sales_system,    credit_info,          at(payment_gateway, payment_gateway_server),   'credit_info:sent_for_approval').
normalized_step(sr22, receive,  payment_gateway, payment_gateway, credit_info,          at(retail_store,    retail_store_office),      'credit_info:received_for_approval').
normalized_step(sr23, generate, retail_store,    sales_system,    item_payment,         at(purchase_request,retail_store_office),      'item_payment:generated').
normalized_step(sr24, send,     retail_store,    sales_system,    item_payment,         at(payment_gateway, payment_gateway_server),   'item_payment:sent_for_approval').
normalized_step(sr25, receive,  payment_gateway, payment_gateway, item_payment,         at(retail_store,    retail_store_office),      'item_payment:received_for_approval').
normalized_step(sr26, approve,  payment_gateway, payment_gateway, item_payment,         at(retail_store,    retail_store_office),      'item_payment:approved').
normalized_step(sr27, send,     retail_store,    sales_system,    item_payment,         at(customer,        customer_device),          'item_payment:sent').
normalized_step(sr28, receive,  customer,        web_browser,     item_payment,         at(retail_store,    retail_store_office),      'item_payment:received').
normalized_step(sr29, pay,      customer,        credit_card,     item_payment,         at(payment_gateway, payment_gateway_server),   'item_payment:paid').
normalized_step(sr30, generate, payment_gateway, payment_gateway, payment_transaction,  at(item_payment,    payment_gateway_server),   'payment_transaction:generated').
normalized_step(sr31, notify,   payment_gateway, payment_gateway, payment_transaction,  at(retail_store,    retail_store_office),      'payment_transaction:notified').
normalized_step(sr32, generate, retail_store,    sales_system,    fulfillment_request,  at(item,            retail_store_warehouse),   'fulfillment_request:generated').
normalized_step(sr33, send,     retail_store,    sales_system,    fulfillment_request,  at(shipper,         shipper_depot),            'fulfillment_request:sent').
normalized_step(sr34, receive,  shipper,         shipper_server,  fulfillment_request,  at(retail_store,    retail_store_warehouse),   'fulfillment_request:received').
normalized_step(sr35, send,     retail_store,    sales_system,    item,                 at(shipper,         shipper_depot),            'item:sent_to_shipper').
normalized_step(sr36, receive,  shipper,         shipper_server,  item,                 at(retail_store,    retail_store_warehouse),   'item:received_by_shipper').
normalized_step(sr37, deliver,  shipper,         shipper_server,  item,                 at(customer,        customer_home),            'item:delivered').
normalized_step(sr38, notify,   shipper,         shipper_server,  item_delivery,        at(retail_store,    retail_store_office),      'item_delivery:notified').
normalized_step(sr39, receive,  retail_store,    sales_system,    item_delivery,        at(shipper,         shipper_depot),            'item_delivery:received').
normalized_step(sr40, generate, retail_store,    sales_system,    item_receipt,         at(item,            retail_store_office),      'item_receipt:generated').
normalized_step(sr41, send,     retail_store,    sales_system,    item_receipt,         at(customer,        customer_email_inbox),     'item_receipt:sent').
normalized_step(sr42, receive,  customer,        customer_email,  item_receipt,         at(retail_store,    retail_store_office),      'item_receipt:received').

% ---------------------------------------------------------------------------
% Accessor
% ---------------------------------------------------------------------------

%! normalized_actions(-Actions:list) is det.
%  Returns the 42 ground-truth actions as action/7 terms, in canonical order.
normalized_actions(Actions) :-
    findall(action(Id, Pat, Actor, Tool, Obj, Aux, Result),
            normalized_step(Id, Pat, Actor, Tool, Obj, Aux, Result),
            Actions).
