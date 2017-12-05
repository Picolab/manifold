ruleset io.picolabs.manifold_pico {
  meta {
    use module io.picolabs.pico alias wrangler
    use module io.picolabs.Tx_Rx alias subscription
    shares subscriptionSpanningTree ,__testing, getManifoldInfo
    provides getManifoldInfo, subscriptionSpanningTree,__testing
  }
  global {
    __testing =
      { "queries": [ { "name":"getManifoldPico" },
                     { "name": "getManifoldInfo" },
                     { "name": "subscriptionSpanningTree" }],
        "events": [ { "domain": "manifold", "type": "create_thing",
                      "attrs": [ "name" ] } ] }

    getManifoldInfo = function(){
      {
        "things": {
          "things": wrangler:children(),
          "thingsPosition": ent:thingsPos.defaultsTo({}),
          "thingsColor": ent:thingsColor.defaultsTo({}),
          "lastUpdated": ent:thingsUpdate.defaultsTo("null")
        }
      }
    }

    addSelf = function(busses){
      busses.map(function(bus){ 
        self = wrangler:skyQuery(bus{"Tx"}, "io.picolabs.pico", "myself");
        bus.put(self);
        });
    }

    subscriptionSpanningTree = function(){ //at root call all subscriptions
      manifold_subs = subscription:established().klog("established()").filter(function(bus){ (bus{"Tx_role"} == "manifold_slave")}).klog("filtered subs on manifold_slave");
      spannedTx     = manifold_subs.map(function(bus){ span(bus) }).reduce(function(a,b){ a.append(b) }); // for all children call established
      addSelf(manifold_subs.append(spannedTx));
    }

    span = function(bus){ // on a single subscription
      //get all subscritpions
      Txs = wrangler:skyQuery(bus{"Tx"}, "io.picolabs.Tx_Rx", "established").filter(function(bus){bus{"Tx_role"} == "manifold_slave" });

      spanSpan = function(Txs){ // on each subscriptions 
        arrayOfTxArrays = Txs.map(function(bus){ span( bus ) }); // get all subscritpions
        arrayOfTxArrays.reduce(function(a,b){ a.append(b) });
      };
      
      (Txs.length() == 0) => [] | Txs.append( spanSpan(Txs) );
    }
    
  }

  rule createThing {
    select when manifold create_thing
    pre {}
    if event:attr("name") then every {
      send_directive("Attempting to create new Thing",{"thing":event:attr("name")})
    }
    fired{
      raise wrangler event "child_creation"
        attributes event:attrs().put({"event_type": "manifold_create_thing"})
                                .put({"rids":"io.picolabs.thing;io.picolabs.Tx_Rx"})
    }else{
      //send_directive("Missing a name for your Thing!")
    }
  }

  rule removeThing {
    select when manifold remove_thing
    pre {}
    if event:attr("name") then every {
      send_directive("Attempting to remove Thing",{"thing":event:attr("name")})
    }
    fired{
      ent:thingsPos := ent:thingsPos.filter(function(v,k){k != event:attr("name")});
      ent:thingsColor := ent:thingsColor.filter(function(v,k){k != event:attr("name")});
      raise wrangler event "child_deletion"
        attributes event:attrs().put({"event_type": "manifold_remove_thing"})
    }else{
      //send_directive("Missing a name for your Thing!")
    }
  }

  rule thingCompleted{
    select when wrangler child_initialized where rs_attrs{"event_type"} == "manifold_create_thing"
    pre{eci = event:attr("eci") }
      event:send(
        { "eci": eci,
          "domain": "wrangler", "type": "autoAcceptConfigUpdate",
          "attrs": {"variable"    : "Tx_Rx_Type",
                    "regex_str"   : "Manifold" }})
    always{
      raise wrangler event "subscription" 
        attributes {"name"        : event:attr("name"),
                    "Rx_role"     : "manifold_master",
                    "Tx_role"     : "manifold_slave",
                    "wellKnown_Tx"   : wrangler:skyQuery( eci , "io.picolabs.Tx_Rx", "wellKnown_Rx"){"id"},
                    "channel_type": "Manifold",
                    "Tx_Rx_Type"  : "Manifold" };  
      ent:thingsUpdate := time:now();
      ent:thingsPos := ent:thingsPos.defaultsTo({}).put([event:attr("name")], {
        "x": 0,
        "y": 0,
        "w": 3,
        "h": 2.25,
        "minw": 3,
        "minh": 2.25,
        "maxw": 8,
        "maxh": 5
      });
      ent:thingsColor := ent:thingsColor.defaultsTo({}).put([event:attr("name")], {
        "color": "#eceff1"
      });
    }
  }

  rule updateLocation {
    select when manifold move_thing
    pre {}
    noop()
    fired {
      ent:thingsPos := ent:thingsPos.defaultsTo({}).put([event:attr("name")], {
        "x": event:attr("x").as("Number"),
        "y": event:attr("y").as("Number"),
        "w": event:attr("w").as("Number"),
        "h": event:attr("h").as("Number"),
        "minw": 3,
        "minh": 2.25,
        "maxw": 8,
        "maxh": 5
      });
    }
  }

  rule colorThing {
    select when manifold color_thing
    pre {}
    noop()
    fired {
      ent:thingsColor := ent:thingsColor.defaultsTo({}).put([event:attr("dname")], {
        "color": event:attr("color")
      });
    }
  }

}//end ruleset
