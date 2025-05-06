// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPermit2 {
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

contract WorldcoinLoteria {
    address public owner;
    IERC20 public wldToken;
    IPermit2 public immutable permit2;
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    enum LoteriaTipo { Stone, Quartz, Citrine, Amethyst, Sapphire, Diamond }

    struct Loteria {
        string nombre;
        uint256 precio;
        uint8 totalBoletos;
        uint8 boletosVendidos;
        mapping(uint8 => address) compradores;
        bool cerrada;
        uint8 numeroGanador;
        uint256 id;
        bool premioPagado;
    }

    struct LoteriaHistorial {
        uint256 id;
        string nombre;
        uint8 numeroGanador;
        address ganador;
        uint256 premio;
        uint256 fechaCierre;
    }

    struct LoteriaView {
        uint id;
        string tipo;
        bool cerrada;
        uint256 numeroGanador;
        uint256 boletosVendidos;
    }

    struct LoteriaResumen {
        uint256 id;
        string nombre;
        uint8 boletosVendidos;
        uint8 totalBoletos;
        bool cerrada;
    }

    struct BoletoUsuario {
        uint256 loteriaId;
        uint8 numero;
    }

    mapping(address => BoletoUsuario[]) public boletosPorUsuario;
    mapping(uint256 => Loteria) public loterias;
    LoteriaHistorial[] public historial;
    uint256 public contadorLoterias;

    event BoletoComprado(uint256 indexed id, address indexed comprador, uint8 numero);
    event LoteriaCerrada(uint256 indexed id, uint8 numeroGanador, address ganador, uint256 premio);

    constructor(address _wldTokenAddress) {
        wldToken = IERC20(_wldTokenAddress);
        permit2 = IPermit2(PERMIT2_ADDRESS);
        owner = msg.sender;

        _crearLoteria("Stone", 0.25 ether);
        _crearLoteria("Quartz", 0.5 ether);
        _crearLoteria("Citrine", 1 ether);
        _crearLoteria("Amethyst", 3 ether);
        _crearLoteria("Sapphire", 5 ether);
        _crearLoteria("Diamond", 10 ether);
    }

    function _crearLoteria(string memory _nombre, uint256 _precio) internal {
        Loteria storage nueva = loterias[contadorLoterias];
        nueva.nombre = _nombre;
        nueva.precio = _precio;
        nueva.totalBoletos = 100;
        nueva.boletosVendidos = 0;
        nueva.id = contadorLoterias;
        nueva.premioPagado = false;
        contadorLoterias++;
    }

    function comprarBoleto(
        uint256 _loteriaId,
        uint8 _numero,
        IPermit2.PermitTransferFrom calldata permit,
        IPermit2.SignatureTransferDetails calldata transferDetails,
        bytes calldata signature
    ) external {
        require(_numero < 100, "Numero invalido");
        Loteria storage loteria = loterias[_loteriaId];
        require(!loteria.cerrada, "Loteria cerrada");
        require(loteria.compradores[_numero] == address(0), "Numero ya comprado");
        require(transferDetails.requestedAmount == loteria.precio, "Monto incorrecto");

        permit2.permitTransferFrom(permit, transferDetails, msg.sender, signature);

        loteria.compradores[_numero] = msg.sender;
        boletosPorUsuario[msg.sender].push(BoletoUsuario({
            loteriaId: _loteriaId,
            numero: _numero
        }));
        loteria.boletosVendidos++;
        emit BoletoComprado(_loteriaId, msg.sender, _numero);

        if (loteria.boletosVendidos == 100) {
            _cerrarLoteria(_loteriaId);
        }
    }

    function comprarBoletos(
        uint256 _loteriaId,
        uint8[] calldata _numeros,
        IPermit2.PermitTransferFrom calldata permit,
        IPermit2.SignatureTransferDetails calldata transferDetails,
        bytes calldata signature
    ) external {
        require(_numeros.length > 0 && _numeros.length <= 10, "Puedes comprar entre 1 y 10 boletos");
        Loteria storage loteria = loterias[_loteriaId];
        require(!loteria.cerrada, "Loteria cerrada");

        uint256 totalPrecio = loteria.precio * _numeros.length;
        require(transferDetails.requestedAmount == totalPrecio, "Monto incorrecto");

        permit2.permitTransferFrom(permit, transferDetails, msg.sender, signature);

        for (uint256 i = 0; i < _numeros.length; i++) {
            uint8 numero = _numeros[i];
            require(numero < 100, "Numero invalido");
            require(loteria.compradores[numero] == address(0), "Numero ya comprado");

            loteria.compradores[numero] = msg.sender;
            boletosPorUsuario[msg.sender].push(BoletoUsuario({
                loteriaId: _loteriaId,
                numero: numero
            }));
            loteria.boletosVendidos++;
            emit BoletoComprado(_loteriaId, msg.sender, numero);
        }

        if (loteria.boletosVendidos == 100) {
            _cerrarLoteria(_loteriaId);
        }
    }

    function verCompradores(uint256 _loteriaId) external view returns (address[100] memory) {
        Loteria storage loteria = loterias[_loteriaId];
        address[100] memory compradores;
        for (uint8 i = 0; i < 100; i++) {
            compradores[i] = loteria.compradores[i];
        }
        return compradores;
    }

    function _cerrarLoteria(uint256 _loteriaId) internal {
        Loteria storage loteria = loterias[_loteriaId];
        require(!loteria.cerrada, "Ya cerrada");

        uint256 aleatorio = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, _loteriaId))) % 100;
        address ganador = loteria.compradores[uint8(aleatorio)];

        uint256 premioTotal = loteria.precio * 100;
        uint256 premioGanador = (premioTotal * 80) / 100;
        uint256 paraOwner = premioTotal - premioGanador;

        require(wldToken.transfer(ganador, premioGanador), "Transferencia al ganador fallida");
        require(wldToken.transfer(owner, paraOwner), "Transferencia al owner fallida");

        loteria.cerrada = true;
        loteria.numeroGanador = uint8(aleatorio);
        loteria.premioPagado = true; 

        historial.push(LoteriaHistorial({
            id: loteria.id,
            nombre: loteria.nombre,
            numeroGanador: loteria.numeroGanador,
            ganador: ganador,
            premio: premioGanador,
            fechaCierre: block.timestamp
        }));

        emit LoteriaCerrada(loteria.id, loteria.numeroGanador, ganador, premioGanador);

        _crearLoteria(loteria.nombre, loteria.precio);
    }

    function rescatarPremio(uint256 _loteriaId) external {
        require(msg.sender == owner, "Solo el owner puede rescatar premios");

        Loteria storage loteria = loterias[_loteriaId];
        require(loteria.cerrada, "La loteria aun no esta cerrada");
        require(!loteria.premioPagado, "Premio ya pagado");

        uint8 numeroGanador = loteria.numeroGanador;
        address ganador = loteria.compradores[numeroGanador];
        require(ganador != address(0), "Ganador no encontrado");

        uint256 premioTotal = loteria.precio * 100;
        uint256 premioGanador = (premioTotal * 80) / 100;
        uint256 paraOwner = premioTotal - premioGanador;

        require(wldToken.transfer(ganador, premioGanador), "Transferencia al ganador fallida");
        require(wldToken.transfer(owner, paraOwner), "Transferencia al owner fallida");

        loteria.premioPagado = true;
    }

    function verNumeroGanador(uint256 _loteriaId) external view returns (uint8) {
        require(loterias[_loteriaId].cerrada, "Loteria no ha finalizado");
        return loterias[_loteriaId].numeroGanador;
    }

    function verHistorial() external view returns (LoteriaHistorial[] memory) {
        return historial;
    }

    function verLoteriasActivas() external view returns (LoteriaResumen[] memory) {
        uint256 total = contadorLoterias;
        uint256 count = 0;

        for (uint256 i = 0; i < total; i++) {
            if (!loterias[i].cerrada) {
                count++;
            }
        }

        LoteriaResumen[] memory activas = new LoteriaResumen[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < total; i++) {
            if (!loterias[i].cerrada) {
                Loteria storage l = loterias[i];
                activas[index] = LoteriaResumen({
                    id: l.id,
                    nombre: l.nombre,
                    boletosVendidos: l.boletosVendidos,
                    totalBoletos: l.totalBoletos,
                    cerrada: l.cerrada
                });
                index++;
            }
        }

        return activas;
    }

    function obtenerBoletosUsuario(address usuario) external view returns (BoletoUsuario[] memory) {
    return boletosPorUsuario[usuario];
}

    function obtenerUltimaLoteriaActivaPorTipo(string memory tipo) public view returns (LoteriaView memory) {
        for (uint256 i = contadorLoterias; i > 0; i--) {
            Loteria storage lot = loterias[i - 1];
            if (
                keccak256(bytes(lot.nombre)) == keccak256(bytes(tipo)) &&
                !lot.cerrada
            ) {
                return LoteriaView({
                    id: lot.id,
                    tipo: lot.nombre,
                    cerrada: lot.cerrada,
                    numeroGanador: lot.numeroGanador,
                    boletosVendidos: lot.boletosVendidos
                });
            }
        }

        revert("No hay loterias activas de este tipo");
    }
}