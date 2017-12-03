ruleset io.picolabs.Tx_Rx {
  meta {
    name "Tx/Rx "
    description <<
      Tx/Rx ruleset for Manifold.
    >>
    author "Tedrub Modulas"
    use module io.picolabs.pico alias wrangler
    provides established, outbound, inbound, wellKnown_Rx, autoAcceptConfig, __testing
    shares   established, outbound, inbound, wellKnown_Rx, autoAcceptConfig, __testing
    logging on
  }

 global{
    __testing = { "queries": [  { "name": "established" },
                                { "name": "outbound"} ,
                                { "name": "inbound"} ,
                                { "name": "wellKnown_Rx"} ,
                                { "name": "autoAcceptConfig"} ],
                  "events": [ { "domain": "wrangler", "type": "subscription",
                                "attrs": [ "name","Rx_role","Tx_role","wellKnown_Tx","channel_type","wild"] },
                              { "domain": "wrangler", "type": "subscription",
                                "attrs": [ "wellKnown_Tx","password"] },
                              { "domain": "wrangler", "type": "pending_subscription_approval",
                                "attrs": [ "Rx" ] },
                              { "domain": "wrangler", "type": "autoAcceptConfigUpdate",
                                "attrs": [ "variable", "regex_str" ] },
                              { "domain": "wrangler", "type": "subscription_cancellation",
                                "attrs": [ "Rx" ] } ]}
/*
ent:inbound [
  {
    "Tx":"", //The channel identifier this pico will send events to
    "Rx":"", //The channel identifier this pico will be listening and receiving events on
    "Tx_role":"", //The subscription role or purpose that the pico on the other side of the subscription serves
    "Rx_role":"", //The role this pico serves, or this picos purpose in relation to the subscription
    "Tx_host": "" //the host location of the other pico if that pico is running on a separate engine
  },...,...
]

ent:outbound [
  {
    "Wellknown_Tx":""}} //only in originating bus, the wellknown is the original channel on which picos are introduced to each other.
    "Tx":"", //The channel identifier this pico will send events to
    "Rx":"", //The channel identifier this pico will be listening and receiving events on
    "Tx_role":"", //The subscription role or purpose that the pico on the other side of the subscription serves
    "Rx_role":"", //The role this pico serves, or this picos purpose in relation to the subscription
    "Tx_host": "" //the host location of the other pico if that pico is running on a separate engine
  },...,...
]

ent:established [
  {
    "Tx":"", //The channel identifier this pico will send events to
    "Rx":"", //The channel identifier this pico will be listening and receiving events on
    "Tx_role":"", //The subscription role or purpose that the pico on the other side of the subscription serves
    "Rx_role":"", //The role this pico serves, or this picos purpose in relation to the subscription
    "Tx_host": "" //the host location of the other pico if that pico is running on a separate engine
  },...,...
]
*/
    autoAcceptConfig = function(){
      ent:autoAcceptConfig.defaultsTo({})
    }
    established = function(){
      ent:established.defaultsTo([])
    }
    outbound = function(){//Tx_Pending
      ent:outbound.defaultsTo([])
    }
    inbound = function(){//Rx_Pending
      ent:inbound.defaultsTo([])
    }
    wellKnown_Rx = function(){
      wrangler:channel("wellKnown_Rx"){"channels"}
    }
      
    indexOfRx = function(buses) { 
      eci = event:attr("Rx").defaultsTo(meta:eci);
      eqaulity = function(bus,eci){ bus{"Rx"} == eci };

      findIndex = function(eqaul, value ,array, i){
        array.length() == 0 => 
                          -1 | 
                          eqaul(array.head() , value) => 
                            i | 
                            findIndex(eqaul, value, array.tail(), i+1 )
      };

      findIndex(eqaulity, eci, buses, 0)
    }

    findBus = function(buses){
      buses.filter( function(bus){ bus{"Rx"} == event:attr("Rx").defaultsTo(meta:eci) }).head();
    }
    randomName = function(){
      random:word() 
    }
    pending_entry = function(){
      {
        "Rx_role"      : event:attr("Rx_role").defaultsTo("peer", "peer used as Rx_role"),
        "Tx_role"      : event:attr("Tx_role").defaultsTo("peer", "peer used as Tx_role"),
        "Tx_host"      : event:attr("Tx_host")
      }
    }

  }

  rule create_wellKnown_Rx{
    select when wrangler ruleset_added where rids >< meta:rid
    pre{ channel = wellKnown_Rx() }
    if(channel.isnull() || channel{"type"} != "Tx_Rx") then
      engine:newChannel(meta:picoId, "wellKnown_Rx", "Tx_Rx")//wrangler:createChannel(...)
    fired{
      raise Tx_Rx event "wellKnown_Rx_created" attributes event:attrs();
    }
    else{
      raise Tx_Rx event "wellKnown_Rx_not_created" attributes event:attrs(); //exists
    }
  }

  //START OF A SUBSCRIPTION'S CREATION
  //For the following comments, consider picoA sending the request to picoB

  rule createRxBus {
    select when wrangler subscription
    pre {
      channel_name  = event:attr("name").defaultsTo(randomName())
      channel_type  = event:attr("channel_type").defaultsTo("Tx_Rx","Tx_Rx channel_type used.")
      pending_entry = pending_entry().put(["wellKnown_Tx"],event:attr("wellKnown_Tx")) //.klog("pending entry")
    }
    if( not pending_entry{"wellKnown_Tx"}.isnull() ) then // check if we have someone to send a request too
      engine:newChannel(meta:picoId, channel_name, channel_type) setting(channel); // create Rx
      //wrangler:createChannel(meta:picoId, event:attr("name") ,channel_type) setting(channel); // create Rx
    fired {
      newBus        = pending_entry.put(["Rx"],channel{"id"});
      ent:outbound := outbound().append( newBus );
      raise wrangler event "pending_subscription" 
        attributes event:attrs().put(newBus.put(["channel_type"], channel_type)
                                           .put(["channel_name"], channel_name))
                                           .put(["status"],"outbound") 
    }
    else {
      raise wrangler event "no_wellKnown_Tx_failure" attributes  event:attrs() // API event
    }
  }//end createMySubscription rule

  rule sendSubscribersSubscribe {
    select when wrangler pending_subscription status re#outbound#
      event:send({
          "eci"   : event:attr("wellKnown_Tx").klog(">> sent Tx_Rx request to >>"),
          "domain": "wrangler", "type": "pending_subscription",
          "attrs" : event:attrs().put(["status"],"inbound")
                                 .put(["Rx_role"], event:attr("Tx_role"))
                                 .put(["Tx_role"], event:attr("Rx_role"))
                                 .put(["Tx"]     , event:attr("Rx"))
                                 .put(["Tx_host"], event:attr("Tx_host").isnull() => null | meta:host)
          }, event:attr("Tx_host"));
  }

 rule addOutboundPendingSubscription {
    select when wrangler pending_subscription status re#outbound#
    always {
      raise wrangler event "outbound_pending_subscription_added" attributes event:attrs()// API event
    }
  }

  rule addInboundPendingSubscription {
    select when wrangler pending_subscription status re#inbound#
   pre {
      pending_entry = pending_entry().put(["Tx"],event:attr("Tx")) //.klog("pending entry")
    }
    if( not pending_entry{"Tx"}.isnull()) then
      engine:newChannel(wrangler:myself(){"id"}, pending_entry{"name"} ,event:attr("channel_type").defaultsTo("Tx_Rx","Tx_Rx channel_type used.")) setting(channel) // create Rx
      //wrangler:createChannel(wrangler:myself(){"id"}, name ,channel_type) setting(channel); // create Rx
    fired {
      newBus       = pending_entry.put(["Rx"],channel{"id"});
      ent:inbound := inbound().append( newBus );
      raise wrangler event "inbound_pending_subscription_added" attributes event:attrs().put(["Rx"],channel{"id"}); // API event
    } 
    else {
      raise wrangler event "no_Tx_failure" attributes  event:attrs() // API event
    }
  }

  rule approveInboundPendingSubscription {
    select when wrangler pending_subscription_approval
    pre{ bus = findBus(inbound()) }
      event:send({
          "eci": bus{"Tx"},
          "domain": "wrangler", "type": "pending_subscription_approved",
          "attrs": {"Tx"     : bus{"Rx"} ,
                    "status" : "outbound",
                    "name"   : bus{"name"} }
          }, bus{"Tx_host"})
    always {
      raise wrangler event "pending_subscription_approved" attributes {
        "Rx" : event:attr("Rx").defaultsTo(meta:eci),
        "status" : "inbound"
      }
    }
  }

  rule addOutboundSubscription {
    select when wrangler pending_subscription_approved status re#outbound#
    pre{
      outbound = outbound().klog("outbound")
      bus      = findBus(outbound)
      index    = indexOfRx(outbound).klog("index")
    }
    always{
      ent:established := established().append(bus);
      ent:outbound    := outbound.splice(index,index + 1 ).klog("0,0");
      raise wrangler event "subscription_added" attributes event:attrs() // API event
    } 
  }

  rule addInboundSubscription {
    select when wrangler pending_subscription_approved status re#inbound#
    pre{
      inbound = inbound()
      bus     = findBus(inbound)
      index   = indexOfRx(inbound)
    }
    always {
      ent:established := established().append(bus);
      ent:inbound     := inbound.splice(index,index + 1);
      raise wrangler event "subscription_added" attributes event:attrs() // API event
    }
  }

  rule cancelSubscription {
    select when wrangler subscription_cancellation
            //or  wrangler inbound_subscription_rejection
            //or  wrangler outbound_subscription_cancellation
    pre{
      bus     = findBus(established())
      Tx_host = bus{"Tx_host"}
    }
    event:send({
          "eci"   : bus{"Tx"},
          "domain": "wrangler", "type": "subscription_removal",
          "attrs" : { "name": event:attr("name") }
          }, Tx_host)
    always {
      raise wrangler event "subscription_removal" attributes event:attrs()
    }
  }

  rule removeSubscription {
    select when wrangler subscription_removal
    pre{
      buses = established()
      bus   = findBus(buses)
      index = indexOfRx(buses)
    }
      engine:removeChannel(bus{"Rx"}) //wrangler:removeChannel ... 
    always {
      ent:established := buses.splice(index,index + 1);
      raise wrangler event "subscription_removed" attributes { "bus" : bus } // API event
    }
  }

  rule autoAccept {
    select when wrangler inbound_pending_subscription_added
    pre{
      /*autoAcceptConfig{
        var : [regex_str,..,..]
      }*/
      matches = ent:autoAcceptConfig.map(function(regs,k) {
                              var = event:attr(k);
                              matches = not var.isnull() => regs.map(function(regex_str){ var.match(regex_str)}).any( function(bool){ bool == true }) | false;
                              matches }).values().any( function(bool){ bool == true })
    }
    if matches.klog("matches") then noop()
    fired {
      raise wrangler event "pending_subscription_approval" attributes event:attrs();  
      raise wrangler event "auto_accepted_Tx_Rx_request" attributes event:attrs();  //API event
    }// else ...
  }

  rule autoAcceptConfigUpdate {
    select when wrangler autoAcceptConfigUpdate
    pre{ config = autoAcceptConfig() }
    if (event:attr("variable") && event:attr("regex_str") ) then noop()
    fired {
      ent:autoAcceptConfig := config.put([event:attr("variable")],config{event:attr("variable")}.defaultsTo([]).append([event:attr("regex_str")])); // possible to add the same regex_str multiple times.
    }
    else {
      raise wrangler event "autoAcceptConfigUpdate_failure" attributes event:attrs() // API event
    }
  }
}