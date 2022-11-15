import { useState, useEffect } from "react";
import { getActivePools } from "../utils/contracts";

export default function AddLiquidity() {
  const [pools, setPools] = useState([]);

  useEffect(() => {
    async function getPools() {
      setPools(JSON.parse(JSON.stringify(await getActivePools())));
    }
    getPools();
  }, []);

  async function onPoolSelected(pool) {
    console.log(pools[pool]);
  }

  return (
    <>
      <select defaultValue="init" onChange={(e) => onPoolSelected(e.target.value)}>
        <option value="init" disabled />
        {Object.keys(pools).map((poolName, index) => (
          <option value={poolName} key={index}>
            {poolName}
          </option>
        ))}
      </select>
    </>
  );
}
