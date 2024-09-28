

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleNftLowerGas is ERC721, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private supply;

    string public uriPrefix = "";
    string public uriSuffix = ".json";
    string public hiddenMetadataUri;

    uint256 public cost = 0.01 ether;
    uint256 public maxSupply = 10000;
    uint256 public maxMintAmountPerTx = 5;

    bool public paused = true;
    bool public revealed = false;

    enum Rareza { Comun, Raro, Epico, Legendario }

    struct NFTDetails {
        Rareza rareza;
        bool fusionado;
    }

    mapping(uint256 => NFTDetails) public nftDetails;

    constructor() ERC721("MyNFT", "MNFT") {
        setHiddenMetadataUri("ipfs://__CID__/hidden.json");
    }

modifier mintCompliance(uint256 _mintAmount) {
    require(_mintAmount > 0 && _mintAmount <= maxMintAmountPerTx);
    require(supply.current() + _mintAmount <= maxSupply);
    _;
}



    function totalSupply() public view returns (uint256) {
        return supply.current();
    }

    function mint(uint256 _mintAmount, Rareza _rareza) public payable mintCompliance(_mintAmount) {
        require(!paused, unicode"El contrato está en pausa");
        require(msg.value >= cost * _mintAmount, unicode"Fondos insuficientes");

        _mintLoop(msg.sender, _mintAmount, _rareza);
    }

    function mintForAddress(uint256 _mintAmount, address _receiver, Rareza _rareza) public mintCompliance(_mintAmount) onlyOwner {
        _mintLoop(_receiver, _mintAmount, _rareza);
    }

    function fusionarNFTs(uint256 tokenId1, uint256 tokenId2) public {
        require(ownerOf(tokenId1) == msg.sender && ownerOf(tokenId2) == msg.sender, "Debes ser propietario de ambos NFTs");
        require(nftDetails[tokenId1].rareza == nftDetails[tokenId2].rareza, "Los NFTs deben tener la misma rareza");
        require(nftDetails[tokenId1].rareza != Rareza.Legendario, "No se puede fusionar un NFT Legendario");

        nftDetails[tokenId1].fusionado = true;
        nftDetails[tokenId2].fusionado = true;

        _burn(tokenId1);
        _burn(tokenId2);

        Rareza nuevaRareza = Rareza(uint(nftDetails[tokenId1].rareza) + 1);
        _mintLoop(msg.sender, 1, nuevaRareza);
    }

    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = 1;
        uint256 ownedTokenIndex = 0;

        while (ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply) {
            address currentTokenOwner = ownerOf(currentTokenId);

            if (currentTokenOwner == _owner) {
                ownedTokenIds[ownedTokenIndex] = currentTokenId;
                ownedTokenIndex++;
            }

            currentTokenId++;
        }

        return ownedTokenIds;
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (revealed == false) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix)) : "";
    }

    function setRevealed(bool _state) public onlyOwner {
        revealed = _state;
    }

    function setCost(uint256 _cost) public onlyOwner {
        cost = _cost;
    }

    function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx) public onlyOwner {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    function withdraw() public onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    function _mintLoop(address _receiver, uint256 _mintAmount, Rareza _rareza) internal {
        for (uint256 i = 0; i < _mintAmount; i++) {
            supply.increment();
            uint256 newTokenId = supply.current();
            _safeMint(_receiver, newTokenId);

            // Establecemos los detalles del NFT con rareza
            nftDetails[newTokenId] = NFTDetails({
                rareza: _rareza,
                fusionado: false
            });
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }
}
