import { setTimer; recurringTimer } "mo:base/Timer";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import { Taggr } "./Canisters";
import Types "./Types";
import Error "mo:base/Error";

actor {
  let sns1GovernancePrincipal = Principal.fromText("zqfso-syaaa-aaaaq-aaafq-cai");

  // initially supported SNS's
  let sns1 : Types.SNSData = {
    governanceCanister = Principal.fromText("zqfso-syaaa-aaaaq-aaafq-cai");
    name = "SNS-1";
    ticker = "SNS";
  };
  let oc : Types.SNSData = {
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

  let header = "# 📰 LATEST SNS PROPOSALS! \n" # "It's time for your daily dose of SNS proposal updates!" # GAP2 # "This bot currently posts the active proposals of the SNS DAO's every day. Owned and controlled by SNS1.";
  let voteSection = "## 🗳️ Where to Vote\n" # "- [ICLighthouse](https://avjzx-pyaaa-aaaaj-aadmq-cai.raw.ic0.app/ICSNS)\n" # "- [OpenChat](https://oc.app/nsbx4-4iaaa-aaaar-afusa-cai) \n" # "- [DSCVR (SNS1 Only)](https://dscvr.one/u/SNSProposalBot) \n";
  let improveMe = "🤖 Help improve me, I'm [open source](https://github.com/syslogica/taggr_sns_bot).\n";

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
  public shared ({ caller }) func snsDataValidator(snsData : Types.SNSDataInput) : async Types.ProposalValidatorResult {
    if (caller != sns1GovernancePrincipal) { return #Err("Unauthorized caller: " # Principal.toText(caller)); };
    switch (validateSnsName(snsData.name)) {
      case (#ok(principal)) {
        switch (await validateSnsGovernancePrincipal(snsData.governanceCanister)) {
          case (#ok(principal)) {
            return #Ok("Add " # snsData.name # " (" # snsData.ticker # ") to @snsproposals taggr bot");
          };
          case (#err(e)) {
            return #Err(e);
          };
        };
      };
      case (#err(e)) {
        return #Err(e);
      };
    };
  };

  public shared ({ caller }) func addNewSns(snsData : Types.SNSDataInput) : async Result.Result<Types.SNSData, Text> {
    if (caller != sns1GovernancePrincipal) { return #err("Unauthorized caller: " # Principal.toText(caller)); };
    let newSnsData : Types.SNSData = {
      governanceCanister = snsData.governanceCanister;
      name = snsData.name;
      ticker = snsData.ticker;
    };

    supportedSNS := Array.append<Types.SNSData>(supportedSNS, [newSnsData]);
    return #ok(newSnsData);
  };

  public shared ({ caller }) func snsRemovalValidator(governancePrincipal : Principal) : async Types.ProposalValidatorResult {
    if (caller != sns1GovernancePrincipal) { return #Err("Unauthorized caller: " # Principal.toText(caller)); };
    let result = await findByPrincipal(governancePrincipal);
    switch(result) {
      case (#err(msg)) {
        return #Err(msg);
      };
      case (#ok(snsData)) {
        return #Ok("Remove " # snsData.name # " (" # snsData.ticker # ") from @snsproposals taggr bot");
      };
    };
  };

  public shared ({ caller }) func removeSns(governancePrincipal : Principal) : async Result.Result<Text, Text> {
    if (caller != sns1GovernancePrincipal) { return #err("Unauthorized caller: " # Principal.toText(caller)); };
    let result = await findByPrincipal(governancePrincipal);
    switch (result) {
      case(#err(msg)) {
        return #err(msg);
      };
      case(#ok(snsData)) {
        supportedSNS := Array.mapFilter<Types.SNSData, Types.SNSData>(supportedSNS, func snsItem = snsItem.governanceCanister != governancePrincipal);
        return #ok("Removed " # snsData.name # " (" # snsData.ticker # ") from @snsproposals taggr bot");
      };
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

  private func findByPrincipal(governancePrincipal : Principal) : async Result.Result<Types.SNSData, Text> {
    let data = Array.find<Types.SNSData>(supportedSNS, func sns = sns.governanceCanister == governancePrincipal);
    switch (data) {
      case (null) {
        return #err("No SNS with that governance principal found");
      };
      case (?snsData) {
        return #ok(snsData);
      };
    };
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

  private func getProposalsFor(principal : Principal) : async [Types.ProposalData] {
    let params : Types.ListProposals = {
      include_reward_status = [];
      before_proposal = null;
      limit = 10;
      exclude_type = [];
      include_status = [1];
    };

    let GovCanister = generateGovActor(principal);
    let response = await GovCanister.list_proposals(params);

    return response.proposals;
  };

  private func formatProposals(proposals : [Types.ProposalData]) : Text {
    var proposalBlock = "";
    var proposal_url = "";

    for (prop in Iter.fromArray(proposals)) {
      switch (prop.proposal) {
        case (?proposal) {
          if (proposal.url != "") {
            proposal_url := "(" # proposal.url # ")";
          };

          let post : Text = "- " # proposal.title # proposal_url # "\n";
          proposalBlock := proposalBlock # post;
        };
        case (_) {};
      };
    };

    return proposalBlock;
  };

  private func validateSnsName(name : Text) : Result.Result<Text, Text> {
    let validName = Array.find<Types.SNSData>(supportedSNS, func x = x.name == name);
    if (validName != null) { return #err("Name already exists") };
    #ok(name);
  };

  private func generateGovActor(principal : Principal) : actor {
      list_proposals : shared query Types.ListProposals -> async Types.ListProposalsResponse;
    } {
    actor (Principal.toText(principal));
  };

  private func validateSnsGovernancePrincipal(principal : Principal) : async Result.Result<Principal, Text> {
    let validGovernancePrincipal = Array.find<Types.SNSData>(supportedSNS, func x = x.governanceCanister == principal);
    if (validGovernancePrincipal != null) {
      return #err("Governance Canister already exists");
    };
    let params : Types.ListProposals = {
      include_reward_status = [];
      before_proposal = null;
      limit = 10;
      exclude_type = [];
      include_status = [1];
    };

    let GovCanister = generateGovActor(principal);
    try {
      let result = await GovCanister.list_proposals(params);
    } catch e {
      throw Error.reject(Principal.toText(principal) # " is not an SNS governance canister");
    };
    #ok(principal);
  };

  ignore setTimer(
    #seconds 10,
    func() : async () {
      ignore recurringTimer(#seconds ONE_DAY_IN_SECONDS, postToTaggr);
      let post = await postToTaggr();
    },
  );

};
