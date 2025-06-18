import { WalletSelector } from "@aptos-labs/wallet-adapter-ant-design";

export default function ConnectButton() {
  return (
    <div className="flex justify-center md:justify-start">
      <WalletSelector />
    </div>
  );
}
