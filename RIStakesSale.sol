pragma solidity ^0.4.13;
library SafeMath {    
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  } 
}

contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public constant returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public constant returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}
contract BasicToken is ERC20Basic {
  using SafeMath for uint256;
  bool teamStakesFrozen = false;
  mapping(address => uint256) balances;
  address public owner;  
  function BasicToken() public {
    owner = msg.sender;
  }  
  modifier notFrozen() {
    require(msg.sender != owner || (msg.sender == owner && !teamStakesFrozen));
    _;
  }
  
  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public notFrozen returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);

    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public constant returns (uint256 balance) {
    return balances[_owner];
  }

}
contract StandardToken is ERC20, BasicToken {
  mapping (address => mapping (address => uint256)) internal allowed;

  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);
    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public notFrozen returns (bool) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  /**
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   */
  function increaseApproval (address _spender, uint _addedValue) public notFrozen returns (bool success) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  function decreaseApproval (address _spender, uint _subtractedValue) public returns (bool success) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

}
contract RI is StandardToken {

  string public constant name = "FundariaToken";
  string public constant symbol = "RI";
  uint8 public constant decimals = 0;
  uint256 public constant INITIAL_SUPPLY = 1957584; // 1957584

  /**
   * @dev Constructor that gives msg.sender all of existing tokens.
   */
  function RI() public {
    totalSupply = INITIAL_SUPPLY;
    balances[msg.sender] = INITIAL_SUPPLY;
  }
}

contract Sale is RI {

    using SafeMath for uint;

/********** 
 * Common *
 **********/

    uint public price = 300; // stakes per 1 ether (aproximatelly $1 per Stake)
    // data to store invested wei value & Stakes for investor
    struct saleData {
      uint stakes;
      uint invested;
    }
    mapping (address=>saleData) public saleStat; // invested value + Stakes data for every investor   
    uint public investedTotal = 0; //how many invested total
    address public pool; // Pool wallet address
    uint public businessPlannedPeriod = 365 days; // total period planned for business activity
    uint public teamCap; // team Stakes capacity
    uint8 public teamShare = 40; // share for team    
    bool public unsoldStakesBurned = false; // have unsold Stakes burned? 

/********** 
 * Bounty *
 **********/
 
    uint public distributedBountyStakes = 0; // bounty advisors Stakes distributed total    
    uint public bountyCap; // bounty advisors Stakes capacity    
    uint8 public bountyShare = 5; // share for bounty    

/************ 
 * Pre sale *
 ************/

    uint public distributedPreSale = 0; // presale distributed stakes to all
    uint public preSaleCap; // pre sale Stakes capacity    
    uint8 public preSaleShare = 10; // share for pre sale    
    uint8 public preSaleStakesSupplyMagnifier = 250; // increaser koef for pre sale Stakes supplying (250 = $0.4)  
    
/********* 
 * Bonus *
 *********/
    
    uint public bonusSaleStartDate = 1511373600; // 1511373600    
    uint public distributedBonusStakes = 0; // bonus sale distributed Stakes total             
    uint public investedToBonusTotal = 0; // total invested wei during bonus sale 
    mapping (address=>uint256) public investedToBonusData; // invested values data for bonus Stakes for every investor    
    address[] public bonusInvestors; // list of investors who bought bonus Stakes       
    uint public bonusCap; // bonus sale Stakes capacity         
    uint public bonusMaxCap; // bonus sale Stakes maximum capacity (to limit increasing of capacity if not all Stakes are sold during pre sale)
    uint8 public bonusShare = 5; // share for bonus sale      
    uint8 public bonusMaxShare = 10; // maximum share for bonus sale (to limit increasing of capacity)   
    bool public bonusSaleStarted = false; // bonus sale started timestamp
    bool public bonusCapReached = false; // bonus Stakes capacity reached
    uint16 public bonusStakesSupplyMagnifier = 200; // increaser of supplying of bonus sale Stakes (200 = $0.5)
    
/*********** 
 * Regular *
 ***********/
    
    uint public regularSaleDate; // bonusSaleStartDate + 3 days
    uint public distributedRegularStakes = 0; // regular distributed stakes to all investors (not pre sale, not bonus, not overcap)
    uint public regularSaleEndDate; // bonusSaleStartDate + 30 days
    uint public regularSaleCap; // regular sale Stakes capacity   
    uint8 public regularSaleShare = 40; // share for regular sale 
            
/*********** 
 * Overcap *
 ***********/    

    uint public investedToOvercapTotal = 0; // total invested to overcap Stakes     
    mapping (address=>saleData) public overcapSaleStat; // saving overcap invested value & overcapped stakes
    address[] public overcapInvestors; // list of investors who invested in overcap Stakes
    uint public overcapInvestmentPlanningPeriod = 31 days;  // 31 days    
    uint8 public overcapStakesSupplyDimmer = 67; // decreaser of supplying of overcap Stakes (67 = Stakes_supplied*67/100 identical to price growing koef 1.5)

/************* 
 * Post sale *
 *************/

    uint8 public postSalePriceMagnifier = 200; // price grows for post sale: (200 = X2)
    bool public postSaleStarted = false; // post sale started timestamp
    
/************* 
 * Promotion *
 *************/
    
    uint public maxAmountForSalePromotion = 30 ether; // How many we can use for promotion of sales
    uint public withdrawnAmountForSalePromotion = 0;    

/********************************************* 
 * To Pool transfers & Investment withdrawal *
 *********************************************/

    uint8 public financePeriodsCount = 12; // How many finance periods in planned period
    uint[] public financePeriodsTimestamps; // Supportive array for searching current finance period
    uint public transferedToPool = 0; // how much wei transfered to pool already

    modifier onlyOwner() {
      require(msg.sender==owner);
      _;
    }
    
    function Sale() public {
      regularSaleDate = bonusSaleStartDate + 3 days;
      regularSaleEndDate = bonusSaleStartDate + 30 days;
      teamCap = totalSupply*teamShare/100; // team stakes capacity     
      bountyCap = totalSupply*bountyShare/100; // bounty stakes capacity
      preSaleCap = totalSupply*preSaleShare/100; // pre sale stakes capacity      
      bonusCap = totalSupply*bonusShare/100;  // bonus sale stakes capacity
      bonusMaxCap = totalSupply*bonusMaxShare/100; // bonus sale stakes maximum capacity
      regularSaleCap = totalSupply*regularSaleShare/100; // regular sale stakes capacity          
      uint financePeriodDuration = businessPlannedPeriod/financePeriodsCount; // quantity of seconds in chosen finance period
      // making array with timestamps of every finance period end date
      for(uint8 i=0; i<financePeriodsCount; i++) {
        financePeriodsTimestamps.push(regularSaleEndDate+financePeriodDuration*(i+1));  
      } 
      //pool = 0x112279df207e408a6d8DA87F37a4a0147ECa8b3F; // initial pool wallet address     
    }
  
  /**
   * @dev Recieve wei and process sale
   */    
    function() payable public {
      require(msg.sender != address(0));
      require(msg.value > 0); // process only requests with wei
      if(now < bonusSaleStartDate){ // pre sale period
        processPreSale();
      } else if(now >= bonusSaleStartDate && now < regularSaleDate) { // bonus sale period
        processBonusSale();
      } else if(now >= regularSaleDate && now < regularSaleEndDate) { // regular sale period
        processRegularSale(msg.value);
      } else if(now >= regularSaleEndDate) { // post sale period
        processPostSale(msg.value);
      }        
    }
  
  /**
   * @dev Pool wallet address needed to store and use wei
   * @param _pool Pool address
   */          
    function setPoolAddress(address _pool) public onlyOwner {
      pool = _pool;  
    }
  
  /**
   * @dev Price is set as stakes per 1 ether
   * @param _price Price in wei
   */      
    function setPrice(uint _price) public onlyOwner returns(uint256) {
      price = _price;
    }

  /**
   * @dev Translate wei to Stakes
   * @param input_wei is wei to translate into stakes, 
   * @param _koef magnifying or dimming supplied stakes
   * @return Stakes quantity        
   */ 
    function stakeForWei(uint input_wei, uint16 _koef) public view returns(uint) {
      return (((input_wei*price)/1000000000000000000) * _koef)/100;    
    }
  
  /**
   * @dev Translate Stakes to wei
   * @param input_stake is stakes to translate into wei
   * @param _koef magnifying or dimming tranlsated wei
   * @return wei quantity        
   */ 
    function weiForStake(uint input_stake, uint16 _koef) public view returns(uint) {
      return (((input_stake*1000000000000000000)/price) * 100)/_koef;
    }
  
  /**
   * @dev Transfer wei from this contract to pool wallet partially only, 
   *      1) for funding promotion of Stakes sale   
   *      2) according to share (finance_periods_last + current_finance_period) / business_planned_period
   */    
    function transferToPool() internal onlyOwner {      
      // promotional funds
      if(now < regularSaleEndDate) {
        require(withdrawnAmountForSalePromotion < maxAmountForSalePromotion); // withdrawn not maximum promotional funds
        // current contract balance + witdrawn promo funds is less or equal to max promo funds
        if(this.balance+withdrawnAmountForSalePromotion <= maxAmountForSalePromotion) {
          withdrawnAmountForSalePromotion += this.balance;
          pool.transfer(this.balance);
        } else {
          // contract balance + witdrawn promo funds more then maximum promotional funds 
          uint dif = maxAmountForSalePromotion - withdrawnAmountForSalePromotion;
          withdrawnAmountForSalePromotion = maxAmountForSalePromotion;
          pool.transfer(dif);
        } 
      } else {
        uint available; // available funds for transfering to pool
        // search end timestamp of current financial period
        for(uint8 i=0; i<financePeriodsCount; i++ ) {
          if(now < financePeriodsTimestamps[i]) { // found end timestamp of current financial period  
            available = ((i+1)*investedTotal)/financePeriodsCount; // avaialbe only part of total value of total invested funds
            // not all available funds are transfered at the moment
            if(available > transferedToPool) {
              pool.transfer(available-transferedToPool);
              transferedToPool = available;             
            }
            break;    
          }
        }
      }      
    }
  
  /**
   * @dev Investor can withdraw part of his/her investment.
   *      A size of this part depends on how many financial periods last and how many remained.
   *      Investor gives back all stakes which he/she got for his/her investment.     
   */       
    function withdrawInvestment() public {
      require(saleStat[msg.sender].stakes > 0);
      require(balances[msg.sender] >= saleStat[msg.sender].stakes); // Investor has needed stakes to return
      require(now > regularSaleEndDate); // do not able to withdraw investment before end of regular sale period
      uint remained; // all investment which are available to withdraw by all investors
      uint to_withdraw; // available funds to withdraw for this particular investor
      for(uint8 i=0; i<financePeriodsCount-1; i++ ) {
        if(now<financePeriodsTimestamps[i]) { // find end timestamp of current financial period
          remained = investedTotal - ((i+2)*investedTotal)/financePeriodsCount; // remained investment to withdraw by all investors 
          to_withdraw = (saleStat[msg.sender].invested*remained)/investedTotal; // investment to withdraw by this investor
          transfer(owner, saleStat[msg.sender].stakes); // return stakes which recieved for investment
          saleStat[msg.sender].stakes = 0;
          investedTotal -= saleStat[msg.sender].invested; // substract invested total value
          saleStat[msg.sender].invested = 0;
          msg.sender.transfer(to_withdraw);
          break;  
        }
      }      
    }

  /**
   * @dev Transfer Stakes from owner balance to buyer balance & saving data to saleStat storage
   * @param address_to is address of buyer 
   * @param _stakes is quantity of Stakes transfered 
   * @param _wei is value invested        
   */ 
    function saleTransfer(address address_to, uint _stakes, uint _wei) internal {
      require(_stakes > 0);
      require(_stakes <= balances[owner]);
      require(balances[owner] > teamCap); // team capacity is not reached still    
      balances[owner] = balances[owner].sub(_stakes); // from
      balances[address_to] = balances[address_to].add(_stakes); // to
      investedTotal += _wei; // adding to total investment
      // saving stat
      saleStat[address_to].invested += _wei;
      saleStat[address_to].stakes += _stakes; 
      Transfer(owner, address_to, _stakes); // eventing  
    }
  
  /**
   * @dev Distribute bounty rewards for bounty tasks
   * @param address_to is address of bounty hunter
   * @param _stakes is quantity of Stakes transfered       
   */     
    function distributeBounty(address address_to, uint _stakes) public onlyOwner {
      require(distributedBountyStakes+_stakes <= bountyCap); // no more then maximum capacity can be distributed
      balances[owner] = balances[owner].sub(_stakes); // from
      balances[address_to] = balances[address_to].add(_stakes); // to
      distributedBountyStakes += _stakes; // adding to total bounty distributed    
    }
  
  /**
   * @dev Process pre sale: supply more Stakes for regular price 
   */       
    function processPreSale() internal {
        uint stakes = 0; // temp stakes value
        uint try_distributed = 0; // how many Stakes will be distributed total with this Stakes
        uint pre_sale_wei = msg.value; // input wei in temp var
      stakes = stakeForWei(msg.value, preSaleStakesSupplyMagnifier); // give more Stakes for regualar price
      // return too small amount
      if(stakes<1) {
        msg.sender.transfer(msg.value);
      } else {
        try_distributed = distributedPreSale+stakes; // how many Stakes will be distributed total with this Stakes
        // presale distributed overcap
        if(try_distributed > preSaleCap) { 
          stakes = preSaleCap-distributedPreSale; // remained Stakes for distribution
          if(stakes>0) {
            pre_sale_wei = weiForStake(stakes, preSaleStakesSupplyMagnifier); // corrected wei for pre sale Stakes
            distributedPreSale = preSaleCap; // pre sale distribution cap reached 100%   
          } else {
            pre_sale_wei = 0;  
          }        
          msg.sender.transfer(msg.value - pre_sale_wei); // return remnant                                   
        } else {
          distributedPreSale = try_distributed;  
        }
        saleTransfer(msg.sender, stakes, pre_sale_wei); // supply  pre sold Stakes to investor        
      }      
    }
  
  /**
   * @dev Process bonus sale: save invested wei value for further distribution of bonus Stakes.
   *      Process regular sale if here are more wei then needed for remained bonus Stakes.   
   */      
    function processBonusSale() internal {
      
      if(bonusSaleStarted == false) {
        // pre sale cap is not reached
        if(distributedPreSale < preSaleCap) {
          // increase bonus capacity on pre sale remnant
          bonusCap += preSaleCap - distributedPreSale;
          if(bonusCap > bonusMaxCap) { // bonus maximum capacity over reached
            regularSaleCap += bonusCap - bonusMaxCap; // transfer over reached Stakes to regular sale cap
            bonusCap = bonusMaxCap;              
          } 
        }
        bonusSaleStarted = true; // for doing this one time only  
      }        
        uint bonus_wei = 0; // wei for bonus Stakes only   
        uint stakes = 0; // temp stakes value
        uint remained_wei = 0; // wei without bonus wei
        uint try_distributed = 0; // how many Stakes will be distributed total with this Stakes
        uint bonus_stakes = 0;
        uint regular_wei = 0;         
      if(!bonusCapReached) { // bonus capacity is not reached yet
        stakes = stakeForWei(msg.value, bonusStakesSupplyMagnifier); // Stakes for all this wei with supply magnifier
        try_distributed = distributedBonusStakes+stakes; // how much will be distributed   
        if(try_distributed > bonusCap) { // if will be distributed more then bonus Stakes capacity
          bonus_stakes = bonusCap - distributedBonusStakes; // remained bonus Stakes
          bonus_wei = weiForStake(bonus_stakes, bonusStakesSupplyMagnifier); // get wei value for bonus Stakes
          remained_wei = msg.value - bonus_wei; // rest value for not bonus Stakes     
          distributedBonusStakes = bonusCap; // bonus cap reached 100%
        } else {
          bonus_wei = msg.value; // all wei for bonus
          distributedBonusStakes += stakes; // add to bonus Stakes total distributed
        }
        if(try_distributed >= bonusCap) {
          bonusCapReached = true;    
        }
        if(investedToBonusData[msg.sender] == 0) {
          bonusInvestors.push(msg.sender); // add investor to list of bonus investors
        }
        investedToBonusData[msg.sender] += bonus_wei; // add invested wei to bonus investors mapping
        investedToBonusTotal += bonus_wei; // increase total invested wei during bonus period 
      }      
      regular_wei = msg.value - bonus_wei; // remained wei
      if(bonusCapReached && regular_wei>0) {
        processRegularSale(regular_wei); // we have Stakes to get regular sale Stakes
      }    
    }
  
  /**
   * @dev Process regular sale: sell Stakes for regular price.
   * @param input_wei is wei value for investment     
   */     
    function processRegularSale(uint input_wei) internal {
      require(input_wei>0);        
        uint stakes = 0; // temp stakes value
        uint try_distributed = 0; // how many Stakes will be distributed total with this Stakes
        uint regular_wei = input_wei;
      stakes = stakeForWei(input_wei, 100); // get Stake for regular price (koef=100)
      // return too small amount
      if(stakes<1) {
        msg.sender.transfer(input_wei);
      } else {
        try_distributed = distributedRegularStakes+stakes; // how many Stakes will be distributed with this Stakes
        if(try_distributed>regularSaleCap) { // overcap detected
          stakes = regularSaleCap-distributedRegularStakes; // remained regular Stakes
          if(stakes>0) {
            regular_wei = weiForStake(stakes, 100); // wei available for buying remained regular Stakes
            distributedRegularStakes = regularSaleCap; // regular distribution capacity reached 100%   
          } else {
            regular_wei = 0;  
          }        
          processOvercapSale(input_wei-regular_wei); // Regular sale capacity reached. Process overcap sale.                        
        } else {
          distributedRegularStakes = try_distributed;  
        }
        saleTransfer(msg.sender, stakes, regular_wei); // distribute Stakes   
      }  
    }
  
  /**
   * @dev Process overcap sale: sell Stakes for regular price but supply less.
   * @param overcap_wei wei value for investment     
   */        
    function processOvercapSale(uint overcap_wei) internal {
      if(overcapSaleStat[msg.sender].invested == 0) {
        overcapInvestors.push(msg.sender); // add investor to overcap investors list 
      }
      overcapSaleStat[msg.sender].stakes += stakeForWei(overcap_wei, overcapStakesSupplyDimmer); // save overcap Stakes for investor
      overcapSaleStat[msg.sender].invested += overcap_wei; // save ovecap wei for investor
      investedToOvercapTotal += overcap_wei; // add this wei to total (all investors) overcap invested value   
    }    
    
    // additional variable for distribution of bonus Stakes in two or more stages
    uint64 bonusInvestorsDistributedCount = 0;
  
  /**
   * @dev Distribute bonus Stakes. Perform after bonus sale period.
   *      Bonus Stakes cap is distributed fully among bonus investors.   
   * @param count how many investors to process (needed if investors too many and cann't process all - out of gas)    
   */  
    function distributeBonusStakes(uint count) public onlyOwner {
//        require(now > regularSaleDate);
        uint invested_to_bonus = 0; // temp value
        uint bonus_investors_distributed_count = bonusInvestorsDistributedCount; // local variable is not changable locally
        if(count==0) count = bonusInvestors.length; // to process all investors
        // process all investors OR determined by count values
        for(uint64 i = bonusInvestorsDistributedCount; i<count+bonus_investors_distributed_count; i++) {
            // this investor is processed
            if(investedToBonusData[bonusInvestors[i]] > 0) {                                         
              invested_to_bonus = investedToBonusData[bonusInvestors[i]]; // invested wei to bonus Stakes by this investor
              investedToBonusData[bonusInvestors[i]] = 0; // nullify for not repeating accidentally               
              saleTransfer(bonusInvestors[i], (bonusCap*invested_to_bonus)/investedToBonusTotal, invested_to_bonus); // distribute bonus Stakes to this investor                    
              bonusInvestorsDistributedCount++; // another bonus investor processed
            }
        }
    }
  
  /**
   * @dev Process post sale: sell Stakes for increased price after end date of regular sale.
   * @param input_wei is wei value for investment     
   */           
    function processPostSale(uint input_wei) public {
      require(input_wei > 0);
      require(now < regularSaleEndDate+businessPlannedPeriod); // business planned period is not finished
      require(distributedRegularStakes < regularSaleCap); // not all stakes for regular sale are sold      
        uint stakes = 0; // temp stakes value
        uint try_distributed = 0;
        uint overcap = 0;
      // automatically increasing price only one, first time      
      if(!postSaleStarted) {
        price = (price*100)/postSalePriceMagnifier; // increasing price for post sale (the bigger price the less Stakes are supplied for 1 ether)
        postSaleStarted = true;
      }    
      stakes = stakeForWei(input_wei, 100);
      // return too small amount
      if(stakes<1) {
        msg.sender.transfer(input_wei); 
      } else {
        try_distributed = distributedRegularStakes+stakes; // check new regular distributed with this Stakes
        if(try_distributed>regularSaleCap) { // overcap
          overcap = try_distributed-regularSaleCap; // how many overcapped
          uint remnant = weiForStake(overcap, 100); // overcap Stakes in wei          
          stakes = regularSaleCap-distributedRegularStakes; // how many Stakes available for sale
          saleTransfer(msg.sender, stakes, input_wei-remnant); // deposit Stakes
          distributedRegularStakes = regularSaleCap; // all Stakes are distributed          
          msg.sender.transfer(remnant); // return remnant
        } else {
          distributedRegularStakes = try_distributed; // increase distributed
          saleTransfer(msg.sender, stakes, input_wei); //deposit stakes 
        }  
      }    
    }
  
  /**
   * @dev Let investors to withdraw their overcap invested wei, if they are not satisfied.
   */     
    function withdrawOvercapWei() public {
      require(overcapSaleStat[msg.sender].invested>0); // sender has overcap invested wei
      //require(now > regularSaleEndDate && now < regularSaleEndDate+overcapInvestmentPlanningPeriod); // now is overcap planning period
      uint overcap_wei = overcapSaleStat[msg.sender].invested; // invested wei
      overcapSaleStat[msg.sender].invested = 0;
      overcapSaleStat[msg.sender].stakes = 0;
      investedToOvercapTotal -= overcap_wei;
      msg.sender.transfer(overcap_wei);          
    }
    
    // additional variable for distribution of overcap Stakes in two or more stages
    uint64 overcapInvestorsDistributedCount = 0;
  
  /**
   * @dev Distribute overcap Stakes. Perform after overcap investment planning period.     
   * @param count how many investors to process (needed if investors too many and cann't process all - out of gas)    
   */  
    function distributeOvercapStakes(uint count) public onlyOwner {
      //require(now > regularSaleEndDate+overcapInvestmentPlanningPeriod);
      //require(postSaleStarted == false);
        uint team_add=0;
        uint overcap_investors_distributed_count = overcapInvestorsDistributedCount; // define local unchangable variable
      if(count==0) count = overcapInvestors.length; // if 0, count all overcap investors
      // process distribution for every overcap investor
      for(uint64 i=overcapInvestorsDistributedCount; i < count+overcap_investors_distributed_count; i++) {
        if(overcapSaleStat[overcapInvestors[i]].invested > 0) { // to not process investor one more time accidentally         
          investedTotal += overcapSaleStat[overcapInvestors[i]].invested; // increase total invested value        
          overcapSaleStat[overcapInvestors[i]].invested = 0;
          team_add = (overcapSaleStat[overcapInvestors[i]].stakes*teamShare)/regularSaleShare; // define team Stakes proportionally too
          teamCap += team_add; // increase team Stakes capacity
          regularSaleCap += overcapSaleStat[overcapInvestors[i]].stakes; // increase regular sale capacity                               
          totalSupply += overcapSaleStat[overcapInvestors[i]].stakes+team_add; // increase totalSupply with new overcap & team Stakes supplied            
          balances[overcapInvestors[i]] = balances[overcapInvestors[i]].add(overcapSaleStat[overcapInvestors[i]].stakes); // increase this investor's balance with overcap Stakes
          balances[owner] = balances[owner].add(team_add);                    
          overcapInvestorsDistributedCount++; // one more overcap investor processed
        }  
      }
    }
  
  /**
   * @dev Burn all unsold Stakes. Only after business planned period.
   */     
    function burnUnsoldStakes() public onlyOwner {
      require(teamStakesFrozen == true); // before team Stakes unfrozen
      require(now > regularSaleEndDate + businessPlannedPeriod); // after end date of business planned period
      // owner balance has more Stakes than team capacity and remained bounty Stakes    
      require(balances[owner] > teamCap+bountyCap-distributedBountyStakes);
      uint overcap = balances[owner] - (teamCap+bountyCap-distributedBountyStakes); // to burn Stakes
      balances[owner] -= overcap; // burn Stakes
      totalSupply -= overcap; // decrease total Stakes supply
      unsoldStakesBurned = true; // to unlock unFreeze 
    }
  
  /**
   * @dev Unfreeze team Stakes. Only after excessed Stakes have burned.
   */      
    function unFreeze() public onlyOwner {
      require(unsoldStakesBurned == true); // only when unsold Stakes where burned
      // only after planned period
      if(now > regularSaleEndDate+businessPlannedPeriod) {
        teamStakesFrozen = false; // make team stakes available for transfering
      }  
    }
}
