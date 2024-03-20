import { Contract, InterfaceAbi, Provider } from "ethers";

const getContractInstance = <T>(address: string, abi: InterfaceAbi, provider: Provider) => (
  new Contract(address, abi, {
    provider,
  })
) as T;

export default getContractInstance
