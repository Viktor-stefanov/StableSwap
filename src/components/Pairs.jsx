import React, { useEffect, useState } from "react";
import { getRelativePrice, swap, getActivePools } from "../utils/contracts";

export default function Pairs() {
  const [pools, setPools] = useState({});
  const [pool, setPool] = useState(null);
  const [fromToken, setFromToken] = useState(null);
  const [toToken, setToToken] = useState(null);
  const [fromTokenAmount, setFromTokenAmount] = useState(null);
  const [toTokenAmount, setToTokenAmount] = useState(null);

  useEffect(() => {
    async function getPools() {
      setPools(JSON.parse(JSON.stringify(await getActivePools())));
    }
    getPools();
  }, []);

  async function calcOtherAmount(amount) {
    if (amount === "") {
      setFromTokenAmount(null);
      setToTokenAmount(null);
      return;
    }

    const equivalentAmount = await getRelativePrice(pool, fromToken, toToken, amount);
    setFromTokenAmount(amount);
    setToTokenAmount(equivalentAmount);
  }

  async function swapTokens() {
    await swap(pool, fromToken, toToken, fromTokenAmount);
  }

  return (
    <>
      <h3>Swap Interface</h3>
      <select defaultValue="init" onChange={(e) => setPool(e.target.value)}>
        <option value="init" disabled />
        {Object.keys(pools).map((poolName, index) => (
          <option value={poolName} key={index}>
            {poolName}
          </option>
        ))}
      </select>
      <br />
      <br />

      {pool && (
        <>
          <span>Select the token to give: </span>
          <select defaultValue="init" onChange={(e) => setFromToken(e.target.value)}>
            <option value="init" disabled />
            {pool.split("/").map((token, index) => (
              <option value={token} key={index}>
                {token}
              </option>
            ))}
          </select>
          <br />

          <span>Select the token to receive: </span>
          <select defaultValue="init" onChange={(e) => setToToken(e.target.value)}>
            <option value="init" disabled />
            {pool.split("/").map((token, index) => (
              <option value={token} key={index}>
                {token}
              </option>
            ))}
          </select>
          <br />

          {fromToken && toToken && (
            <>
              <span>Enter {fromToken} amount: </span>
              <input onInput={(e) => calcOtherAmount(e.target.value)} />
              {toTokenAmount && (
                <>
                  <p>
                    {fromTokenAmount} {fromToken} is exchangable for {toTokenAmount} {toToken}
                  </p>
                  <button onClick={swapTokens}>Swap</button>
                </>
              )}
            </>
          )}
        </>
      )}
    </>
  );
}
