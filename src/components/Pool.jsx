import { useState, useEffect } from "react";
import AddLiquidity from "./AddLiquidity";
import { provideLiquidity, getAllTokens, estimateBalancedDeposit } from "../utils/contracts";

export default function Pool() {
  const [createPool, setCreatePool] = useState(null);
  const [tokens, setTokens] = useState([]);
  const [fromToken, setFromToken] = useState(null);
  const [fromTokenAmount, setFromTokenAmount] = useState(null);
  const [toToken, setToToken] = useState(null);
  const [toTokenAmount, setToTokenAmount] = useState(null);
  const [depositing, setDepositing] = useState(false);

  useEffect(() => {
    async function getTokens() {
      setTokens(await getAllTokens());
    }
    getTokens();
  }, []);

  async function calcOtherAmount(amount, inputDirection) {
    if (amount === "") {
      setFromTokenAmount(null);
      setToTokenAmount(null);
      return;
    }

    const otherAmount = await estimateBalancedDeposit(fromToken, toToken, amount, inputDirection);
    if (inputDirection === "fromTo") {
      setFromTokenAmount(amount);
      setToTokenAmount(otherAmount);
    } else {
      setToTokenAmount(amount);
      setFromTokenAmount(otherAmount);
    }
  }

  async function startPooling() {
    setDepositing(true);
    await provideLiquidity(fromToken, fromTokenAmount, toToken, toTokenAmount);
    setFromTokenAmount(null);
    setToTokenAmount(null);
    setDepositing(false);
  }

  return (
    <>
      <button onClick={() => setCreatePool(false)}>Add Liquidity to Existing Pool</button>
      <button onClick={() => setCreatePool(true)}>Create a Liquidity Pool</button>
      <br />
      <br />

      {createPool === false && <AddLiquidity />}
    </>
  );
}
