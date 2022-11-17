import { useState, useEffect } from "react";
import { deposit, getActivePools, estimatePoolPrices } from "../utils/contracts";

export default function AddLiquidity() {
  const [pools, setPools] = useState([]);
  const [pool, setPool] = useState(null);
  const [tokenAmounts, setTokenAmounts] = useState({});
  const [inputFilled, setInputFilled] = useState(null);

  useEffect(() => {
    async function getPools() {
      setPools(JSON.parse(JSON.stringify(await getActivePools())));
    }
    getPools();
  }, []);

  async function onTokenAmountChange(token, amount) {
    setTokenAmounts(await estimatePoolPrices(pool, token, amount));
    setInputFilled(true);
  }

  async function depositFunds() {
    await deposit(pool, tokenAmounts);
  }

  return (
    <>
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
          {pools[pool].map((token, index) => (
            <div key={index}>
              <span>Enter amount of {token}: </span>
              <input
                type="number"
                value={tokenAmounts[token] || ""}
                onChange={(e) => onTokenAmountChange(token, e.target.value)}
              />
              <br />
            </div>
          ))}
          {inputFilled && <button onClick={depositFunds}>Deposit Funds</button>}
        </>
      )}
    </>
  );
}
