import { AptosWalletAdapterProvider } from "@aptos-labs/wallet-adapter-react";
import { Network } from "@aptos-labs/ts-sdk";
import { PetraWallet } from "petra-plugin-wallet-adapter";
import "@aptos-labs/wallet-adapter-ant-design/dist/index.css";

export default function WalletProvider({ children }) {
  return (
    <AptosWalletAdapterProvider
      autoConnect
      dappConfig={{ network: Network.DEVNET }}
      optInWallets={["Petra"]}         /* add "Martian" etc. later */
    >
      {children}
    </AptosWalletAdapterProvider>
  );
}
