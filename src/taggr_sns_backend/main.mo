import { setTimer; recurringTimer } "mo:base/Timer";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import { Taggr } "./Canisters";
import Types "./Types";

actor {
  let sns1GovernanceCanister = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");

  // initially supported SNS's
  let sns1 : Types.SNSData = {
    id = 1;
    governanceCanister = Principal.fromText("zqfso-syaaa-aaaaq-aaafq-cai");  
    name = "SNS-1";
    ticker = "SNS";
  };
  let oc : Types.SNSData = { 
    id = 2;
    governanceCanister = Principal.fromText("2jvtu-yqaaa-aaaaq-aaama-cai");  
    name = "OpenChat";
    ticker = "CHAT";
  };

  stable var previousPost : Text = "";
  stable var lastTaggrResponse : Types.TaggrResult = #Err("No response yet");
  stable var supportedSNS : [Types.SNSData] = [sns1, oc];

  let ONE_DAY_IN_SECONDS = 86401;
  let GAP4 = "\n\n\n\n";
  let GAP2 = "\n\n";

  let header = "# 📰 LATEST SNS PROPOSALS! \n" 
    # "It's time for your daily dose of SNS proposal updates!" 
    # GAP2 
    # "This bot currently posts the active proposals of the SNS DAO's every day. Owned and controlled by SNS1.";

  let voteSection = "## 🗳️ Where to Vote\n"
    # "- [ICLighthouse](https://avjzx-pyaaa-aaaaj-aadmq-cai.raw.ic0.app/ICSNS)\n"
    # "- [OpenChat](https://oc.app/nsbx4-4iaaa-aaaar-afusa-cai) \n" 
    # "- [DSCVR (SNS1 Only)](https://dscvr.one/u/SNSProposalBot) \n";

  let improveMe = "🤖 Help improve me, I'm [open source](https://github.com/nolyoi/taggr_sns_bot).\n";



  // PUBLIC QUERY FUNCS
  public query func lastPost() : async Text {
    return previousPost;
  };

  public query func lastResponse() : async Types.TaggrResult {
    return lastTaggrResponse;
  };

  public query func supportedProjects() : async [Types.SNSData] {
    return supportedSNS;
  };



  // GENERIC NERVOUS SYSTEM FUNCS AND VALIDATORS
  // have to use custom result type here because the format is different between rust and motoko, SNS expects the rust format.
  public shared ({caller}) func snsDataValidator(snsData : Types.SNSDataInput) : async Types.ProposalValidatorResult {
    if(caller == sns1GovernanceCanister){ 
      let validName = Array.find<Types.SNSData>(supportedSNS, func x = x.name == snsData.name);
      let validGovernancePrincipal = Array.find<Types.SNSData>(supportedSNS, func x = x.governanceCanister == snsData.governanceCanister);
      
      if (validName != null) {
        return #Err("Name already exists");
      } else if(validGovernancePrincipal != null) {
        return #Err("Governance Canister already exists");
      };

      let params = {
        include_reward_status : [Int32] = [];
        before_proposal : ?Types.ProposalId = null;
        limit : Nat32 = 10;
        exclude_type : [Nat64] = [];
        include_status : [Int32] = [1];
      };

      let GovCanister : actor {
        list_proposals : shared query Types.ListProposals -> async Types.ListProposalsResponse;
      } = actor (Principal.toText(snsData.governanceCanister));

      try { 
        let result = await GovCanister.list_proposals(params); 
      } catch e {
        return #Err(Principal.toText(snsData.governanceCanister) # " is not an SNS governance canister");
      };

      #Ok("Proposal to add " # snsData.name # " to the snsproposals Taggr bot" );
    } else {
      #Err("Unauthorized principal: " # Principal.toText(caller));
    };
  };

  public shared ({caller}) func addSnsData(snsData : Types.SNSDataInput) : async Result.Result<Types.SNSData, Text> {
    if(caller == sns1GovernanceCanister){ 
      let newSnsCanister : Types.SNSData = {
        id = supportedSNS.size() + 1;
        governanceCanister = snsData.governanceCanister;
        name = snsData.name;
        ticker = snsData.ticker;
      };

      supportedSNS := Array.append<Types.SNSData>(supportedSNS, [newSnsCanister]);
      #ok(newSnsCanister)
    } else {
      #err("Unauthorized principal: " # Principal.toText(caller));
    };
  };



  // PRIVATE FUNCS
  private func postToTaggr() : async () {
    let post = await generateCurrentPost();
    lastTaggrResponse := await Taggr.add_post(post, [], null, ?"SNS-1");
  };

  private func generateCurrentPost() : async Text {
    var proposalsBlock : Text = "";

    for (source in Iter.fromArray(supportedSNS)) {
      let sourceProposals = await generateProposalsBlock(source);
      proposalsBlock := proposalsBlock # sourceProposals;
    };

    previousPost := header # GAP4 # proposalsBlock # voteSection # GAP2 # improveMe # GAP2;

    return previousPost;
  };

  private func generateProposalsBlock(snsData : Types.SNSData) : async Text {
    let proposals = await getProposalsFor(snsData.governanceCanister);
    let formattedProposals = formatProposals(proposals);
    let sourceTitle = "## 🟢 Active on " # "#" # snsData.name # "\n";

    if (Array.size(proposals) > 0) {
      return sourceTitle # formattedProposals;
    } else {
      return sourceTitle # "- No active proposals at this time.\n";
    };
  };

  public func getProposalsFor(principal : Principal) : async [Types.ProposalData] {
    let params = {
      include_reward_status : [Int32] = [];
      before_proposal : ?Types.ProposalId = null;
      limit : Nat32 = 10;
      exclude_type : [Nat64] = [];
      include_status : [Int32] = [1];
    };

    let GovCanister : actor {
      list_proposals : shared query Types.ListProposals -> async Types.ListProposalsResponse;
    } = actor (Principal.toText(principal));

    let response = await GovCanister.list_proposals(params);
    return response.proposals
  };

  private func formatProposals(proposals : [Types.ProposalData]) : Text {
    var proposalBlock = "";
    var proposal_url = "";

    for (prop in Iter.fromArray(proposals)) {
      switch (prop.proposal) {
        case (?proposal) {
          if(proposal.url != ""){ proposal_url := "(" # proposal.url # ") \n" };

          let post : Text = "- " # proposal.title # proposal_url;
          proposalBlock := proposalBlock # post;
        };
        case (_) {};
      };
    };

    return proposalBlock;
  };

  ignore setTimer(
    #seconds 10,
    func() : async () {
      ignore recurringTimer(#seconds ONE_DAY_IN_SECONDS, postToTaggr);
      return ();
    },
  );

};