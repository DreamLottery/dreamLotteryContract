// scripts/deploy.ts
import { ethers } from "hardhat";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("🚀 Desplegando contrato con la cuenta:", deployer.address);

    const wldTokenAddress = "0x2cfc85d8e48f8eab294be644d9e25c3030863003";

    // Obtener datos de gas recomendados por la red
    const feeData = await deployer.provider!.getFeeData();
    console.log("⛽ Gas price recomendado:", ethers.formatUnits(feeData.gasPrice!, "gwei"), "Gwei");

    // Obtener la fábrica del contrato
    console.log("🔨 Obteniendo Factory...");
    const WorldcoinLoteria = await ethers.getContractFactory("WorldcoinLoteria", deployer);

    // Estimar gas antes de desplegar
    console.log("📊 Estimando gas...");
    const deployTransaction = WorldcoinLoteria.getDeployTransaction(wldTokenAddress);

    const estimatedGas = await deployer.provider!.estimateGas({
        from: deployer.address,
        to: undefined,
        data: (await deployTransaction).data,
    });

    console.log("⛽ Gas estimado para el despliegue:", estimatedGas.toString());

    console.log("🚀 Desplegando contrato...");
    const contract = await WorldcoinLoteria.deploy(wldTokenAddress,{
        gasLimit: estimatedGas,
        gasPrice: feeData.gasPrice!,
    });

    console.log("⏳ Esperando confirmación...");
    await contract.waitForDeployment();

    console.log("✅ Contrato desplegado en:", await contract.getAddress());
}

main().catch((error) => {
    console.error("❌ Error en el despliegue:", error);
    process.exitCode = 1;
});
