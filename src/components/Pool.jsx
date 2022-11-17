import { useState } from "react";
import AddLiquidity from "./AddLiquidity";

export default function Pool() {
  const [createPool, setCreatePool] = useState(null);

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
