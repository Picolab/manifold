ruleset io.picolabs.manifold_owner {
  meta {
    use module io.picolabs.wrangler alias wrangler
    shares __testing, getManifoldPico
  }
  global {
    __testing =
      { "queries": [ { "name": "__testing", "name":"getManifoldPico" } ],
        "events": [ { "domain": "manifold", "type": "channel_needed",
                      "attrs": [ "eci_to_manifold_child" ] } ,
                    { "domain": "wrangler", "type": "ruleset_added",
                      "attrs": [  ] }
                   ] }

    config={"pico_name" : "Manifold", "URI" : ["io.picolabs.manifold_pico.krl"], "rids": ["io.picolabs.manifold_pico"], "channel_type":"App"};

    getManifoldPico = function(){
      child = wrangler:children(config{"pico_name"}){"children"};
      child.length() > 0 =>  child[0] | "No Manifold Pico"
    }
    getManifoldEci = function(channels){
      manifolds = channels.filter(function(chan){chan{"name"} == config{"pico_name"} && chan{"type"} == config{"channel_type"}})
      manifolds.head(){"eci"}
    }
  }
  rule manifold_needed {
    select when manifold channel_needed
    pre {
      child = getManifoldPico();
    }
    if child ! = "No Manifold Pico" then every {
      send_directive("manifold still being created",{})
    }fired{last}
  }

  rule channel_needed {
    select when manifold channel_needed
    pre {
      child = getManifoldPico();
      channels = engine:listChannels(child{"id"});
      eci = getManifoldEci(channels);
    }
    if not eci then every {
      engine:newChannel(child{"id"},config{"pico_name"},config{"channel_type"})
        setting(new_channel)
      send_directive("manifold new channel",{
        "eci": new_channel{"id"}.klog("new eci created:")})
    }
    fired{last}
  }
  rule channel_needed {
    select when manifold channel_needed
    pre {
      child = getManifoldPico();
      channels = engine:listChannels(child{"id"});
      eci = getManifoldEci(channels);
    }
    if eci then every {
        send_directive("manifold channel",{
          "eci": eci.klog("manifold eci:")})
    }
    fired{last}
  }
  rule initialization {
    select when wrangler ruleset_added where rids.klog("rids") >< meta:rid.klog("meta rid")
    pre {
      manifoldPico =  getManifoldPico()
    }
    if manifoldPico == "No Manifold Pico" then
      engine:registerRuleset(config{"URI"}[0].klog("URI used:"),meta:rulesetURI.klog("Path used"))
    fired {
      raise wrangler event "child_creation" // HEY HEY!!!! check event api
        attributes { "name": config{"pico_name"}, "color": "#7FFFD4", "rids": config{"rids"} } // check child creation api
    }
  }
}
