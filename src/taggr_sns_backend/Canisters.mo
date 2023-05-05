import Types "./Types";

module Canisters {
  public let Taggr : actor {
    add_post : shared (Text, [(Text, Blob)], ?Nat64, ?Text) -> async {
      #Ok : Nat64;
      #Err : Text;
    };
  } = actor ("6qfxa-ryaaa-aaaai-qbhsq-cai");
};
