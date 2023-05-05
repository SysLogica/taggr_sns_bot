import { setTimer; recurringTimer } "mo:base/Timer";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import { Taggr } "./Canisters";
import Types "./Types";

actor {
  // initially supported SNS's
  let sns1 : Types.SNSCanister = { 
    governanceCanister = Principal.fromText("zqfso-syaaa-aaaaq-aaafq-cai");  
    name = "SNS-1";
    ticker = "SNS";
  };
  let oc : Types.SNSCanister = { 
    governanceCanister = Principal.fromText("2jvtu-yqaaa-aaaaq-aaama-cai");  
    name = "OpenChat";
    ticker = "CHAT";
  };

  stable var previousPost : Text = "";
  stable var lastTaggrResponse : Types.TaggrResult = #Err("No response yet");
  stable var snsCanisters : [Types.SNSCanister] = [sns1, oc];

  let ONE_DAY_IN_SECONDS = 86401;
  let THREE_DAYS_IN_SECONDS = 259200;
  let GAP4 = "\n\n\n\n";
  let GAP2 = "\n\n";

  let header = "# 📰 LATEST SNS PROPOSALS! \n" 
    # "It's time for your daily dose of SNS proposal updates!" 
    # GAP2 
    # "This bot currently posts the active proposals of the #SNS1 and #OpenChat DAO's every day.";

  let voteSection = "## 🗳️ Where to Vote\n"
    # "- [ICLighthouse](https://avjzx-pyaaa-aaaaj-aadmq-cai.raw.ic0.app/ICSNS)\n"
    # "- [OpenChat](https://oc.app/nsbx4-4iaaa-aaaar-afusa-cai) \n" 
    # "- [DSCVR](https://dscvr.one/u/SNSProposalBot) \n";

  let improveMe = "🤖 Help improve me, I'm [open source](https://github.com/nolyoi/taggr_sns_bot).\n";

  public query func lastPost() : async Text {
    return previousPost;
  };

  public query func lastResponse() : async Types.TaggrResult {
    return lastTaggrResponse;
  };

  public query func supportedSNSCanisters() : async [Types.SNSCanister] {
    return snsCanisters;
  };

  private func postToTaggr() : async () {
    let post = await generateCurrentPost();
    lastTaggrResponse := await Taggr.add_post(post, [], null, ?"SNS-1");
  };

  private func generateCurrentPost() : async Text {
    var proposalsBlock : Text = "";

    for (source in Iter.fromArray(snsCanisters)) {
      let sourceProposals = await generateProposalsBlock(source);
      proposalsBlock := proposalsBlock # sourceProposals;
    };

    previousPost := header # GAP4 # proposalsBlock # voteSection # GAP2 # improveMe # GAP2;
    return previousPost;
  };

  private func generateProposalsBlock(snsCanister : Types.SNSCanister) : async Text {
    let proposals = await getProposalsFor(snsCanister);
    let formattedProposals = formatProposals(proposals);
    let sourceTitle = "## 🟢 Active on " # snsCanister.name # "\n";

    if (Array.size(proposals) > 0) {
      return sourceTitle # formattedProposals;
    } else {
      return sourceTitle # "- No active proposals at this time.\n";
    };
  };

  private func getProposalsFor(snsCanister : Types.SNSCanister) : async [Types.ProposalData] {
    let params = {
      include_reward_status : [Int32] = [];
      before_proposal : ?Types.ProposalId = null;
      limit : Nat32 = 10;
      exclude_type : [Nat64] = [];
      include_status : [Int32] = [1];
    };

    let GovCanister : actor {
      list_proposals : shared query Types.ListProposals -> async Types.ListProposalsResponse;
    } = actor (Principal.toText(snsCanister.governanceCanister));

    let response = await GovCanister.list_proposals(params);

    return response.proposals
  };

  private func formatProposals(proposals : [Types.ProposalData]) : Text {
    var proposalBlock = "";

    for (prop in Iter.fromArray(proposals)) {
      switch (prop.proposal) {
        case (?proposal) {
          let post : Text = "- " # proposal.title # "(" # proposal.url # ") \n";
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
