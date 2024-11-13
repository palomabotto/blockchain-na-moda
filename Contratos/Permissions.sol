// Administrador: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
// Fornecedor: 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
// Fabricante: 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
// Distribuidor: 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
// Varejista: 0x617F2E2fD72FD9D5503197092aC168c91465E7f2
// Pessoa comum sem Role e possível comprador: 0x17F6AD8Ef982297579C203069C1DbfFE4348c372


// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

// Contrato para gerenciar permissões e rastrear produtos na cadeia de suprimentos
contract Permissions {
    address public immutable admin; // Endereço do administrador do contrato

    // Mapeamentos para identificar permissões de diferentes papéis na cadeia de suprimentos
    mapping(address => bool) private fornecedores;
    mapping(address => bool) private fabricantes;
    mapping(address => bool) private distribuidores;
    mapping(address => bool) private varejistas;

    mapping(address => bool) public registeredAccounts; // Contas registradas no sistema

    // Estrutura para armazenar informações de produtos
    struct Product {
        uint id;
        string name;
        address currentOwner;
        bool manufactured; 
        bool finalized;
    }

    uint public productCounter; // Contador de produtos
    mapping(uint => Product) public products; // Armazena os produtos registrados

    // Eventos para acompanhar ações no contrato
    event ProductCreated(uint indexed productId, string name, address indexed owner);
    event ProductManufactured(uint productId, address manufacturer);
    event ProductTransferred(uint indexed productId, address indexed from, address indexed to);
    event UnregisteredAccountAccessAttempt(address account, string role);

    constructor() {
        admin = msg.sender; // Define o criador do contrato como administrador
    }

    // Modificadores para restringir acesso com base em permissões
    modifier onlyAdmin() {
        require(msg.sender == admin, "Somente o administrador pode executar essa acao.");
        _;
    }

    modifier onlyFornecedor() {
        require(fornecedores[msg.sender], "Somente o fornecedor pode executar essa acao.");
        _;
    }

    modifier onlyFabricante() {
        require(fabricantes[msg.sender], "Somente o fabricante pode executar essa acao.");
        _;
    }

    modifier onlyDistribuidor() {
        require(distribuidores[msg.sender], "Somente o distribuidor pode executar essa acao.");
        _;
    }

    modifier onlyVarejista() {
        require(varejistas[msg.sender], "Somente o varejista pode executar essa acao.");
        _;
    }

    // Atribui um papel a um endereço específico
    function assignRoleToUser(address stakeholderAddress, string memory _role) public onlyAdmin {
        require(stakeholderAddress != address(0), "Endereco invalido.");
        bytes32 roleHash = keccak256(bytes(_role));

        // Valida o papel e registra a conta
        require(
            roleHash == keccak256(bytes("FORNECEDOR")) ||
            roleHash == keccak256(bytes("FABRICANTE")) ||
            roleHash == keccak256(bytes("DISTRIBUIDOR")) ||
            roleHash == keccak256(bytes("VAREJISTA")),
            "Papel invalido."
        );

        registeredAccounts[stakeholderAddress] = true;

        if (roleHash == keccak256(bytes("FORNECEDOR"))) {
            fornecedores[stakeholderAddress] = true;
        } else if (roleHash == keccak256(bytes("FABRICANTE"))) {
            fabricantes[stakeholderAddress] = true;
        } else if (roleHash == keccak256(bytes("DISTRIBUIDOR"))) {
            distribuidores[stakeholderAddress] = true;
        } else if (roleHash == keccak256(bytes("VAREJISTA"))) {
            varejistas[stakeholderAddress] = true;
        }
    }

    // Remove um papel de um endereço
    function revokeRoleFromUser(address stakeholderAddress, string memory _role) public onlyAdmin {
        require(stakeholderAddress != address(0), "Endereco invalido.");
        bytes32 roleHash = keccak256(bytes(_role));

        require(registeredAccounts[stakeholderAddress], "Conta nao registrada.");

        if (roleHash == keccak256(bytes("FORNECEDOR"))) {
            fornecedores[stakeholderAddress] = false;
        } else if (roleHash == keccak256(bytes("FABRICANTE"))) {
            fabricantes[stakeholderAddress] = false;
        } else if (roleHash == keccak256(bytes("DISTRIBUIDOR"))) {
            distribuidores[stakeholderAddress] = false;
        } else if (roleHash == keccak256(bytes("VAREJISTA"))) {
            varejistas[stakeholderAddress] = false;
        } else {
            revert("Role invalido.");
        }

        // Desregistra a conta caso todos os papéis sejam revogados
        if (
            !fornecedores[stakeholderAddress] &&
            !fabricantes[stakeholderAddress] &&
            !distribuidores[stakeholderAddress] &&
            !varejistas[stakeholderAddress]
        ) {
            registeredAccounts[stakeholderAddress] = false;
        }
    }

    // Revoga todos os papéis de um endereço
    function revokeAllRoles(address stakeholderAddress) public onlyAdmin {
        require(stakeholderAddress != address(0), "Endereco invalido.");
        require(registeredAccounts[stakeholderAddress], "Conta nao registrada.");

        fornecedores[stakeholderAddress] = false;
        fabricantes[stakeholderAddress] = false;
        distribuidores[stakeholderAddress] = false;
        varejistas[stakeholderAddress] = false;

        registeredAccounts[stakeholderAddress] = false;
    }

    // Verifica se uma conta possui um papel específico
    function checkRole(address account, string memory _role) public returns (bool) {
        if (!registeredAccounts[account]) {
            emit UnregisteredAccountAccessAttempt(account, _role);
            return false;
        }

        bytes32 roleHash = keccak256(bytes(_role));

        if (roleHash == keccak256(bytes("FORNECEDOR"))) {
            return fornecedores[account];
        } else if (roleHash == keccak256(bytes("FABRICANTE"))) {
            return fabricantes[account];
        } else if (roleHash == keccak256(bytes("DISTRIBUIDOR"))) {
            return distribuidores[account];
        } else if (roleHash == keccak256(bytes("VAREJISTA"))) {
            return varejistas[account];
        }
        return false;
    }

    // Função para o Fornecedor criar um material inicial
    function createMaterial(string memory _name) public onlyFornecedor {
        require(bytes(_name).length > 0, "Nome do material nao pode ser vazio.");
        productCounter++;
        products[productCounter] = Product(productCounter, _name, msg.sender, false, false);
        emit ProductCreated(productCounter, _name, msg.sender);
    }

    function getProductsByOwner(address owner) public view returns (uint[] memory) {
        uint count = 0;

        // Conta quantos produtos pertencem ao proprietário atual
        for (uint i = 1; i <= productCounter; i++) {
            if (products[i].currentOwner == owner) {
                count++;
            }
        }

        // Cria uma lista para armazenar os IDs dos produtos
        uint[] memory result = new uint[](count);
        uint index = 0;

        for (uint i = 1; i <= productCounter; i++) {
            if (products[i].currentOwner == owner) {
                result[index] = i;
                index++;
            }
        }

        return result;
    }

    // Função para transferir o produto entre os papéis da cadeia
    function transferProduct(uint _productId, address _to) public {
        require(products[_productId].currentOwner == msg.sender, "Apenas o dono atual pode transferir.");
        require(!products[_productId].finalized, "Produto ja finalizado, nao pode ser transferido.");
        require(fornecedores[_to] || fabricantes[_to] || distribuidores[_to] || varejistas[_to], "Destinatario nao autorizado.");
        
        products[_productId].currentOwner = _to;
        emit ProductTransferred(_productId, msg.sender, _to);
    }


    // Função para o Fabricante transformar o material em um produto
    function manufactureProduct(uint _productId) public onlyFabricante {
        require(products[_productId].currentOwner != address(0), "Produto nao encontrado.");
        require(!products[_productId].finalized, "Produto ja finalizado e nao pode ser alterado.");
        require(!products[_productId].manufactured, "Produto ja foi fabricado.");

        
        products[_productId].manufactured = true;
        emit ProductManufactured(_productId, msg.sender);

    }

    // // Função para o Distribuidor transferir o produto
    // function distributeProduct(uint _productId, address _to) public onlyDistribuidor {
    //     require(products[_productId].currentOwner == msg.sender, "Apenas o dono atual pode transferir.");
    //     require(!products[_productId].finalized, "Produto ja finalizado, nao pode ser transferido.");
    //     require(fornecedores[_to] || fabricantes[_to] || distribuidores[_to] || varejistas[_to], "Destinatario nao autorizado.");
    //     products[_productId].currentOwner = _to;
    //     emit ProductTransferred(_productId, msg.sender, _to);
    // }

    // Função para o Varejista vender o produto final
    function sellProduct(uint _productId, address _to) public onlyVarejista {
        require(products[_productId].currentOwner == msg.sender, "Apenas o dono atual pode vender.");
        require(!products[_productId].finalized, "Produto ja finalizado.");
        markAsFinalized(_productId);
        products[_productId].currentOwner = _to; // Venda realizada

        emit ProductTransferred(_productId, msg.sender, _to);
    }

    // Função para marcar um produto como finalizado
    function markAsFinalized(uint _productId) private onlyVarejista {
        require(products[_productId].currentOwner == msg.sender, "Somente o Varejista pode finalizar.");
        require(!products[_productId].finalized, "Produto ja finalizado.");
        products[_productId].finalized = true;
    }
}
