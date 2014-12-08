require 'nokogiri'
require 'fileutils'

def generate(filepath)
  filePath = filepath
  fileDir = filePath.slice(0..filePath.rindex('\\'))


  f = File.open(filePath)
  doc = Nokogiri::XML(f)
  f.close

  doc = doc.xpath('npnets:PetriNetNestedMarked')
  systemNet = doc.xpath('child::net')[0]
  elementNets = systemNet.xpath('//typeElementNet')

  package = systemNet.xpath('netSystem')[0]['name'].gsub(' ', '_')

  genPath = fileDir + "output\\java\\#{package}"

  if (!File.directory?(genPath))
    FileUtils.mkdir_p genPath
  end

  systemPlaces = systemNet.xpath('netSystem/places')

  (0..systemPlaces.count-1).each do |i|
    placeName = systemPlaces[i]['name']
    arcsIds = systemPlaces[i]['outArcs'].delete('#').split

    placeType = systemPlaces[i]['type'].delete('#')

    transitionsNames = []
    (0..arcsIds.count-1).each do |i|
      transitionsId = systemNet.xpath("netSystem/arcsPT[@id='#{arcsIds[i]}']/@outTransition").to_s.delete('#')
      transitionsNames.push(systemNet.xpath("netSystem/transitions[@id='#{transitionsId}']/@name").to_s)
    end

    transitionsBlock = ''
    notifyBlock = ''
    (0..transitionsNames.count-1).each do |i|
      transitionsBlock << "@EJB\n#{transitionsNames[i]}Bean #{transitionsNames[i]};\n"
      notifyBlock << "#{transitionsNames[i]}.reciveNotification(name, true);\n"
    end

    variablesBlock = ""
    createBlock =""
    if (systemNet.xpath("typeAtomic[@id='#{placeType}']").count == 1)
      variablesBlock = "String type = \"black\";
    Integer idCounter = 0;"
      createBlock="public void createToken() {
        idCounter++;
        list.add(type + \"_\" + name + \"_\" + idCounter);
        notifyTransitions();
    }"
    end

    initBlock = ""
    markings = doc.xpath("marking/map[@place='##{systemPlaces[i]['id']}']")
    puts placeName
    (0..markings.count-1).each do |i|
      markingType = markings[i].xpath("marking/@type")[0].to_s.delete('#')
      if (systemNet.xpath("typeAtomic[@id='#{markingType}']").count == 1)
        initBlock << "createToken();\n"
      else
        token = markings[i].xpath("marking/weight/@token")[0].to_s.delete('#')
        weight = markings[i].xpath("marking/weight/@weight")[0].to_s.to_i
        marking = doc.xpath("//tokenNets[@id=#{token}]/@value")[0].to_s.delete('#')
        net = doc.xpath("//tokenNets[@id=#{token}]/ancestor::typeElementNet/@name")[0]
        if (!variablesBlock.include?("#{net}ManagerBean"))
          variablesBlock << "@EJB\n#{net}ManagerBean #{net}Manager;\n"
        end

        (0..weight-1).each do |j|
          initBlock << "addToken(#{net}Manager.createToken(\"#{marking}\"));\n"
        end
      end

      if (i == markings.count - 1)
        initBlock << "notifyTransitions();\n"
      end
    end


    placeBean = "package #{package};

import java.util.ArrayList;
import java.util.List;
import javax.annotation.PostConstruct;
import javax.ejb.EJB;
import java.util.Timer;
import java.util.TimerTask;
import javax.ejb.Singleton;
import javax.ejb.Startup;


@Startup
@Singleton
public class #{placeName}Bean {


    #{transitionsBlock}

    List<String> list = new ArrayList<String>();
    String name = \"#{placeName}\";

    #{variablesBlock}
    Timer timer = new Timer();

    String blocked = \"\";

    @PostConstruct
    void init() {
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                #{initBlock}
            }
        }, 1000);

    }

    public void notifyTransitions() {
        if(!list.isEmpty())
        {
            #{notifyBlock}
        } else
        {
            #{notifyBlock.gsub('true', 'false')}
        }
    }

    public Boolean blockPosition(String name) {
        if((blocked.equals(\"\") || blocked.equals(name)) && (!list.isEmpty()))
        {
            blocked = name;
            return true;
        }

        return false;
    }

    public void unblockPosition(String name) {
        if(blocked.equals(name) || blocked.equals(\"\"))
        {
            blocked = \"\";
            notifyTransitions();
        }
    }

    public String getFirstToken() {
        return list.get(0);
    }

    public List<String> getTokens() {
        return list;
    }

    public void removeToken(String id) {
        list.remove(list.indexOf(id));
    }

    public void addToken(String id) {
        list.add(id);
        if(blocked.equals(\"\"))
            notifyTransitions();
    }

    #{createBlock}

}
"
    File.open("#{genPath}\\#{placeName}Bean.java", 'w') do |f|
      f.puts placeBean
    end


  end

  systemTransitions = systemNet.xpath('netSystem/transitions')

  (0..systemTransitions.count-1).each do |i|
    transName = systemTransitions[i]['name']
    arcsPTIds = systemTransitions[i]['inArcs'].delete('#').split
    arcsTPIds = systemTransitions[i]['outArcs'].delete('#').split

    synch = {}
    if (!systemTransitions[i]['synchronization'].nil?)
      synchId = systemTransitions[i]['synchronization'].delete('#').split
      synchName = elementNets.xpath("net/transitions[@synchronization='##{synchId[0]}']/@name").to_s
      synchType = elementNets.xpath("net/transitions[@synchronization='##{synchId[0]}']/ancestor::typeElementNet/@id").to_s
      synch.store(synchName, synchType)
    end

    inputVariables = {}
    inputTypes = {}
    (0..arcsPTIds.count-1).each do |i|
      placesId = systemNet.xpath("netSystem/arcsPT[@id='#{arcsPTIds[i]}']/@inPlace").to_s.delete('#')
      variableId = systemNet.xpath("netSystem/arcsPT[@id='#{arcsPTIds[i]}']/inscription/monoms/@variable").to_s.delete('#')
      inputName = systemNet.xpath("netSystem/places[@id='#{placesId}']/@name").to_s
      inputVariable = systemNet.xpath("netSystem/transitions/variables[@id='#{variableId}']/@name").to_s
      inputType = systemNet.xpath("netSystem/places[@id='#{placesId}']/@type").to_s
      inputVariables.store(inputName, inputVariable)
      inputTypes.store(inputName, inputType)
    end

    outputs = {}
    (0..arcsTPIds.count-1).each do |i|
      placesId = systemNet.xpath("netSystem/arcsTP[@id='#{arcsTPIds[i]}']/@outPlace").to_s.delete('#')
      variableId = systemNet.xpath("netSystem/arcsTP[@id='#{arcsTPIds[i]}']/inscription/monoms/@variable").to_s.delete('#')
      outputName = systemNet.xpath("netSystem/places[@id='#{placesId}']/@name").to_s
      outputVariable = systemNet.xpath("netSystem/transitions/variables[@id='#{variableId}']/@name").to_s
      outputs.store(outputName, outputVariable)
    end

    variablesBlock = ''
    variables = inputVariables.merge(outputs).merge(synch)
    (0..variables.count-1).each do |i|
      variablesBlock << "@EJB\n#{variables.keys[i]}Bean #{variables.keys[i]};\n"
    end

    inputsBlock = ''
    (0..inputVariables.count-1).each do |i|
      inputsBlock << "inputs.put(\"#{inputVariables.keys[i]}\", false);\n"
    end

    blockBlock = "blocked = blocked"
    (0..inputVariables.count-1).each do |i|
      blockBlock << " && #{inputVariables.keys[i]}.blockPosition(name)"
    end
    blockBlock << ";"

    unblockBlock = ""
    (0..inputVariables.count-1).each do |i|
      unblockBlock << "#{inputVariables.keys[i]}.unblockPosition(name);\n"
    end

    triggerBlock = ''
    if (synch.count == 0)
      triggerBlock << "String token;\n"
      blackInput = inputVariables.select { |k, v| systemNet.xpath("typeAtomic[@id='#{inputTypes[k].delete('#')}']").count == 1 }
      (0..blackInput.count-1).each do |i|
        triggerBlock << "token = #{blackInput.keys[i]}.getFirstToken();\n#{blackInput.keys[i]}.removeToken(token);\n"
      end

      blackOutput= outputs.select { |k, v| blackInput.has_value?(v) }
      (0..blackOutput.count-1).each do |i|
        triggerBlock << "#{blackOutput.keys[i]}.createToken();\n"
      end

      nonblackInput = inputVariables.select { |k, v| !blackInput.has_key?(k) }
      (0..nonblackInput.count-1).each do |i|
        triggerBlock << "token = #{nonblackInput.keys[i]}.getFirstToken();\n#{nonblackInput.keys[i]}.removeToken(token);\n"

        nonblackOutput = outputs.select { |k, v| v == nonblackInput.values[i] }
        if (nonblackOutput.count == 0)
          netManagerType = systemNet.xpath("netSystem/places[@name='#{nonblackOutput.keys[0]}']/@type").to_s.delete('#')
          netManager = doc.xpath("typeElementNet[@id='#{netManagerType}']/@name")
          if (!variablesBlock.include?("#{netManager[0]}ManagerBean"))
            variablesBlock << "@EJB\n#{netManager[0]}ManagerBean #{netManager[0]}Manager;\n"
          end
          triggerBlock << "#{netManager}Manager.removeToken(token);\n"
        elsif (nonblackOutput.count == 1)
          triggerBlock << "#{nonblackOutput.keys[0]}.addToken(token);\n"
        elsif (nonblackOutput.count > 1)
          netManagerType = systemNet.xpath("netSystem/places[@name='#{nonblackOutput.keys[0]}']/@type").to_s.delete('#')
          netManager = doc.xpath("typeElementNet[@id='#{netManagerType}']/@name")
          if (!variablesBlock.include?("#{netManager[0]}ManagerBean"))
            variablesBlock << "@EJB\n#{netManager[0]}ManagerBean #{netManager[0]}Manager;\n"
          end
          triggerBlock << "#{nonblackOutput.keys[0]}.addToken(token);\n"
          (1..nonblackOutput.count-1).each do |i|
            triggerBlock << "token = #{netManager}Manager.cloneToken(token);\n"
            triggerBlock << "#{nonblackOutput.keys[i]}.addToken(token);\n"
          end
        end
      end

      triggerBlock = "#{triggerBlock}doExtraStuff();\nunblockInputs();\n"
    else
      triggerBlock << 'boolean fullSynch = true;
            List<String> synch = new ArrayList<String>();
            List<String> keys = new ArrayList<String>();'

      synchedInputs = inputVariables.select { |k, v| synch.has_value?(inputTypes[k].delete('#')) }
      synchedElements = []
      (0..synchedInputs.count-1).each do |i|
        element = synch.keys[synch.values.index(inputTypes[synchedInputs.keys[i]].delete('#'))]
        if (!synchedElements.include?(element))
          synchedElements.push(element)
        end
        triggerBlock << "keys = #{synchedInputs.keys[i]}.getTokens();
                       fullSynch = false;
                       for(int i = 0; i<keys.size(); i++)
                       {
                           if(#{element}.synchronize(keys.get(i), name))
                           {
                              synch.add(keys.get(i));
                               fullSynch = true;
                               break;
                           }
                       }
                       if(!fullSynch)
                       {
                           synch.add(\"\");
                       }"
      end

      triggerBlock << "fullSynch = true;
                     for(int i = 0; i<synch.size(); i++)
                         if(synch.get(i).equals(\"\"))
                             fullSynch = false;

                     if(fullSynch)
                     {
                          String token;"

      (0..synchedElements.count-1).each do |i|
        triggerBlock << "#{synchedElements[i]}.triggerTransition(synch.get(#{i}));\n"
      end

      blackInput = inputVariables.select { |k, v| systemNet.xpath("typeAtomic[@id='#{inputTypes[k].delete('#')}']").count == 1 }
      (0..blackInput.count-1).each do |i|
        triggerBlock << "token = #{blackInput.keys[i]}.getFirstToken();\n#{blackInput.keys[i]}.removeToken(token);\n"
      end

      blackOutput= outputs.select { |k, v| blackInput.has_value?(v) }
      (0..blackOutput.count-1).each do |i|
        triggerBlock << "#{blackOutput.keys[i]}.createToken();\n"
      end

      nonblackInput = inputVariables.select { |k, v| !blackInput.has_key?(k) }
      (0..nonblackInput.count-1).each do |i|
        triggerBlock << "token = synch.get(#{i});\n#{nonblackInput.keys[i]}.removeToken(token);\n"

        nonblackOutput = outputs.select { |k, v| v == nonblackInput.values[i] }
        if (nonblackOutput.count == 0)
          netManagerType = systemNet.xpath("netSystem/places[@name='#{nonblackOutput.keys[0]}']/@type").to_s.delete('#')
          netManager = doc.xpath("typeElementNet[@id='#{netManagerType}']/@name")
          if (!variablesBlock.include?("#{netManager[0]}ManagerBean"))
            variablesBlock << "@EJB\n#{netManager[0]}ManagerBean #{netManager[0]}Manager;\n"
          end
          triggerBlock << "#{netManager}Manager.removeToken(token);\n"
        elsif (nonblackOutput.count == 1)
          triggerBlock << "#{nonblackOutput.keys[0]}.addToken(token);\n"
        elsif (nonblackOutput.count > 1)
          netManagerType = systemNet.xpath("netSystem/places[@name='#{nonblackOutput.keys[0]}']/@type").to_s.delete('#')
          netManager = doc.xpath("typeElementNet[@id='#{netManagerType}']/@name")
          if (!variablesBlock.include?("#{netManager[0]}ManagerBean"))
            variablesBlock << "@EJB\n#{netManager[0]}ManagerBean #{netManager[0]}Manager;\n"
          end
          triggerBlock << "#{nonblackOutput.keys[0]}.addToken(token);\n"
          (1..nonblackOutput.count-1).each do |i|
            triggerBlock << "token = #{netManager}Manager.cloneToken(token);\n"
            triggerBlock << "#{nonblackOutput.keys[i]}.addToken(token);\n"
          end
        end
      end

      triggerBlock << 'doExtraStuff();
                     unblockInputs();
                 } else {'

      (0..synchedElements.count-1).each do |i|
        triggerBlock << "#{synchedElements[i]}.removeSynchronization(synch.get(#{i}), name);\n"
      end

      triggerBlock << 'if (!waiting4Check) {
                        Timer timer = timerService.createTimer(duration, null);
                        waiting4Check = true;
                     }
                     unblockInputs();
                }'
    end

    importBlock = ''
    extraBlock = ''
    actionBlock = ''
    if (File.exists?(fileDir+transName+'.txt'))
      part = '%import%'
      File.open(fileDir+transName+'.txt', "r") do |infile|
        while (line = infile.gets)
          if (line[0] == '%')
            part = line.chop
          else
            if (part == '%import%')
              importBlock << line
            elsif (part == '%extra%')
              extraBlock << line
            elsif (part == '%action%')
              actionBlock << line
            end
          end
        end
      end
    end

    if (extraBlock == '')
      extraBlock = "return true;\n"
    end

    transBean = "package #{package};

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.annotation.PostConstruct;
import javax.annotation.Resource;
import javax.ejb.EJB;
import javax.ejb.Singleton;
import javax.ejb.Startup;
import javax.ejb.Timeout;
import javax.ejb.Timer;
import javax.ejb.TimerService;
#{importBlock}


@Startup
@Singleton
public class #{transName}Bean {

    #{variablesBlock}

    @Resource
    TimerService timerService;
    long duration = 50;

    Map<String, Boolean> inputs = new HashMap<String, Boolean>();
    String name = \"#{transName}\";
    boolean inWork = false;
    boolean waiting4Check = false;


    @PostConstruct
    void init() {
        #{inputsBlock}
    }

    public void reciveNotification(String name, Boolean status) {
        inputs.put(name, status);
        checkInputs();
    }

    @Timeout
    public void timeout() {
        waiting4Check = false;
        checkInputs();
    }

    private void checkInputs()
    {
        if(inWork)
        {
            if (!waiting4Check) {
                Timer timer = timerService.createTimer(duration, null);
                waiting4Check = true;
            }
            return;
        }

        inWork = true;
        boolean inputsFull = true;
        List<Boolean> list =  new ArrayList<Boolean>(inputs.values());
        for(int i = 0; i < inputs.size(); i++)
        {
            inputsFull = inputsFull && list.get(i);
        }

        if(inputsFull)
        {
            triggerTransition();
        }

        inWork = false;
    }

    private void triggerTransition() {
        if (blockInputs() && checkExtra()) {

          #{triggerBlock}

        } else {
            if (!waiting4Check) {
                Timer timer = timerService.createTimer(duration, null);
                waiting4Check = true;
            }
        }
    }

    private boolean blockInputs() {
        boolean blocked = true;
        #{blockBlock}

        if (!blocked) {
            unblockInputs();
        }

        return blocked;
    }

    private void unblockInputs()
    {
        #{unblockBlock}
    }
    private boolean checkExtra() {
        #{extraBlock}
    }

    private void doExtraStuff() {
        #{actionBlock}
    }

}"

    File.open("#{genPath}\\#{transName}Bean.java", 'w') do |f|
      f.puts transBean
    end
  end

  (0..elementNets.count-1).each do |en|

    elementPlaces = elementNets[en].xpath('net/places')

    (0..elementPlaces.count-1).each do |j|
      placeName = elementPlaces[j]['name']
      arcsIds = elementPlaces[j]['outArcs'].delete('#').split

      placeType = elementPlaces[j]['type'].delete('#')

      transitionsNames = []
      (0..arcsIds.count-1).each do |j|
        transitionsId = elementNets[en].xpath("net/arcsPT[@id='#{arcsIds[j]}']/@outTransition").to_s.delete('#')
        transitionsNames.push(elementNets[en].xpath("net/transitions[@id='#{transitionsId}']/@name").to_s)
      end

      transitionsBlock = ''
      notifyBlock = ''
      (0..transitionsNames.count-1).each do |i|
        transitionsBlock << "@EJB\n#{transitionsNames[i]}Bean #{transitionsNames[i]};\n"
        notifyBlock << "#{transitionsNames[i]}.reciveNotification(keys.get(i), name, true);\n"
      end


      placeBean = "package #{package};

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.annotation.PostConstruct;
import javax.ejb.EJB;

import javax.ejb.Singleton;
import javax.ejb.Startup;

@Startup
@Singleton
public class #{placeName}Bean {

    #{transitionsBlock}

    List<String> keys = new ArrayList<String>();
    Map<String, List<String>> list = new HashMap<String, List<String>>();
    String type = \"black\";
    String name = \"#{placeName}\";
    Integer idCounter = 0;

    Map<String, String> blocked = new HashMap<String, String>();

    @PostConstruct
    void init() {

    }

    public void notifyTransitions() {
        List<String> tmpList;
        for (int i = 0; i < keys.size(); i++) {
            tmpList = list.get(keys.get(i));
            if (!tmpList.isEmpty()) {
                #{notifyBlock}

            } else {
                #{notifyBlock.gsub('true', 'false')}
            }
        }
    }

    public Boolean blockPosition(String key, String name) {
        if((blocked.get(key).equals(\"\") || blocked.get(key).equals(name)) && (!list.get(key).isEmpty()))
        {
            blocked.put(key, name);
            return true;
        }

        return false;
    }

    public void unblockPosition(String key, String name) {
        if(blocked.get(key).equals(name))
        {
            blocked.put(key, \"\");
            notifyTransitions();
        }
    }

    public String getFirstToken(String key) {
        return list.get(key).get(0);
    }

    public List<String> getTokens(String key) {
        return list.get(key);
    }

    public void removeToken(String key, String id) {
        list.get(key).remove(list.get(key).indexOf(id));
    }

    public void addToken(String key, String id) {
        list.get(key).add(id);
        if(blocked.get(key).equals(\"\"))
            notifyTransitions();
    }

    public void createToken(String key) {
        idCounter++;
        list.get(key).add(type + \"_\" + name + \"_\" + idCounter);
        notifyTransitions();
    }

    public void createNetToken(String key)
    {
        keys.add(key);
        list.put(key, new ArrayList<String>());
        blocked.put(key, \"\");
    }

    public void destroyNetToken(String key)
    {
        keys.remove(key);
        list.remove(key);
        blocked.remove(key);
    }
}
"
      File.open("#{genPath}\\#{placeName}Bean.java", 'w') do |f|
        f.puts placeBean
      end


    end

    elementTransitions = elementNets[en].xpath('net/transitions')

    (0..elementTransitions.count-1).each do |i|
      transName = elementTransitions[i]['name']
      arcsPTIds = elementTransitions[i]['inArcs'].delete('#').split
      arcsTPIds = elementTransitions[i]['outArcs'].delete('#').split

      synch = false
      if (!elementTransitions[i]['synchronization'].nil?)
        synch = true
      end

      inputVariables = {}
      (0..arcsPTIds.count-1).each do |i|
        placesId = elementNets[en].xpath("net/arcsPT[@id='#{arcsPTIds[i]}']/@inPlace").to_s.delete('#')
        variableId = elementNets[en].xpath("net/arcsPT[@id='#{arcsPTIds[i]}']/inscription/monoms/@variable").to_s.delete('#')
        inputName = elementNets[en].xpath("net/places[@id='#{placesId}']/@name").to_s
        inputVariable = elementNets[en].xpath("net/transitions/variables[@id='#{variableId}']/@name").to_s
        inputVariables.store(inputName, inputVariable)
      end

      outputs = {}
      (0..arcsTPIds.count-1).each do |i|
        placesId = elementNets[en].xpath("net/arcsTP[@id='#{arcsTPIds[i]}']/@outPlace").to_s.delete('#')
        variableId = elementNets[en].xpath("net/arcsTP[@id='#{arcsTPIds[i]}']/inscription/monoms/@variable").to_s.delete('#')
        outputName = elementNets[en].xpath("net/places[@id='#{placesId}']/@name").to_s
        outputVariable = elementNets[en].xpath("net/transitions/variables[@id='#{variableId}']/@name").to_s
        outputs.store(outputName, outputVariable)
      end

      variablesBlock = ''
      variables = inputVariables.merge(outputs)
      (0..variables.count-1).each do |i|
        variablesBlock << "@EJB\n#{variables.keys[i]}Bean #{variables.keys[i]};\n"
      end

      inputsBlock = ''
      (0..inputVariables.count-1).each do |i|
        inputsBlock << "map.put(\"#{inputVariables.keys[i]}\", false);\n"
      end

      blockBlock = "blocked = blocked"
      (0..inputVariables.count-1).each do |i|
        blockBlock << " && #{inputVariables.keys[i]}.blockPosition(key, name)"
      end
      blockBlock << ";"

      unblockBlock = ""
      (0..inputVariables.count-1).each do |i|
        unblockBlock << "#{inputVariables.keys[i]}.unblockPosition(key, name);\n"
      end

      triggerBlock = ""

      triggerBlock << "String token;\n"
      (0..inputVariables.count-1).each do |i|
        triggerBlock << "token = #{inputVariables.keys[i]}.getFirstToken(key);\n#{inputVariables.keys[i]}.removeToken(key, token);\n"
      end

      (0..outputs.count-1).each do |i|
        triggerBlock << "#{outputs.keys[i]}.createToken(key);\n"
      end

      importBlock = ''
      extraBlock = ''
      actionBlock = ''
      if (File.exists?(fileDir+transName+'.txt'))
        part = '%import%'
        File.open(fileDir+transName+'.txt', "r") do |infile|
          while (line = infile.gets)
            if (line[0] == '%')
              part = line.chop
            else
              if (part == '%import%')
                importBlock << line
              elsif (part == '%extra%')
                extraBlock << line
              elsif (part == '%action%')
                actionBlock << line
              end
            end
          end
        end
      end

      if (extraBlock == '')
        extraBlock = "return true;\n"
      end

      if (!synch)

        transBean = "
package #{package};

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.annotation.PostConstruct;
import javax.annotation.Resource;
import javax.ejb.EJB;
import javax.ejb.Singleton;
import javax.ejb.Startup;
import javax.ejb.Timeout;
import javax.ejb.Timer;
import javax.ejb.TimerService;

#{importBlock}

@Startup
@Singleton
public class #{transName}Bean {


    #{variablesBlock}

    @Resource
    TimerService timerService;
    long duration = 50;

    Map<String, Map<String, Boolean>> inputs = new HashMap<String, Map<String, Boolean>>();
    String name = \"#{transName}\";

    boolean inWork = false;
    List<String> waiting4Check = new ArrayList<String>() ;


    @PostConstruct
    void init() {
    }

    public void reciveNotification(String key, String name, Boolean status) {
        inputs.get(key).put(name, status);
        checkInputs(key);
    }

    @Timeout
    public void timeout() {
        if (!waiting4Check.isEmpty()) {
            String waitingKey = waiting4Check.get(0);
            waiting4Check.remove(waitingKey);
            checkInputs(waitingKey);
        }
    }

    private void checkInputs(String key)
    {
        if(inWork)
        {
            if(!waiting4Check.contains(key))
            {
                Timer timer = timerService.createTimer(duration, null);
                waiting4Check.add(key);
            }
            return;
        }
        inWork = true;


        boolean inputsFull = true;
        List<Boolean> list = new ArrayList<Boolean>(inputs.get(key).values());
        for (int i = 0; i < inputs.get(key).size(); i++) {
            inputsFull = inputsFull && list.get(i);
        }

        if (inputsFull) {
            triggerTransition(key);
        } else {
            unblockInputs(key);
        }


        inWork = false;
            //checkInputs();
    }

    private void triggerTransition(final String key)
    {
        if(!blockInputs(key))
        {
            Timer timer = timerService.createTimer(duration, null);
            waiting4Check.add(key);
        } else if(checkExtra(key))
        {

            #{triggerBlock}

            doExtraStuff(key);
            unblockInputs(key);

        }
    }

    private boolean blockInputs(String key) {
        boolean blocked = true;
        #{blockBlock}

        if (!blocked) {
            unblockInputs(key);
        }

        return blocked;
    }

    private void unblockInputs(String key) {
        #{unblockBlock}
    }

    private boolean checkExtra(String key) {
        #{extraBlock}
    }

    private void doExtraStuff(String key) {
        #{actionBlock}
    }

    public void createNetToken(String key)
    {
        Map<String, Boolean> map = new HashMap<String, Boolean>();
        #{inputsBlock}
        inputs.put(key, map);;
    }

    public void destroyNetToken(String key)
    {
        inputs.remove(key);
        waiting4Check.remove(key);
    }
}"
      else


        transBean = "package #{package};

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.annotation.PostConstruct;
import javax.ejb.EJB;
import javax.ejb.Singleton;
import javax.ejb.Startup;
#{importBlock}


@Startup
@Singleton
public class #{transName}Bean {


    #{variablesBlock}

    Map<String, Map<String, Boolean>> inputs = new HashMap<String, Map<String, Boolean>>();
    String name = \"#{transName}\";
    Map<String, String> synch = new HashMap<String, String>();

    @PostConstruct
    void init() {
    }

    public void reciveNotification(String key, String name, Boolean status) {
        inputs.get(key).put(name, status);
        //checkInputs(key);
    }

    public boolean synchronize(String key, String name) {
        if (synch.get(key).equals(\"\") || synch.get(key).equals(name)) {
            boolean inputsFull = true;
            List<Boolean> list =  new ArrayList<Boolean>(inputs.get(key).values());
            for (int i = 0; i < inputs.get(key).size(); i++) {
                inputsFull = inputsFull && list.get(i);
            }

            if (inputsFull && blockInputs(key) && checkExtra(key)) {
                synch.put(key, name);
                return true;
            } else {
                unblockInputs(key);
            }
            return false;
        } else
        {
            return false;
        }
    }

    public void removeSynchronization(String key, String name) {
        if(!key.equals(\"\") && synch.get(key).equals(name))
        {
            synch.put(key, \"\");
            unblockInputs(key);
        }
    }


    public void triggerTransition(String key) {
        #{triggerBlock}

        doExtraStuff(key);
        unblockInputs(key);
        synch.put(key, \"\");
    }


    private boolean blockInputs(String key) {
        boolean blocked = true;
        #{blockBlock}

        if (!blocked) {
            unblockInputs(key);
        }

        return blocked;
    }

    private void unblockInputs(String key) {
        #{unblockBlock}
    }

    private boolean checkExtra(String key) {
        #{extraBlock}
    }

    private void doExtraStuff(String key) {
        #{actionBlock}
    }

    public void createNetToken(String key)
    {
        Map<String, Boolean> map = new HashMap<String, Boolean>();
        #{inputsBlock}
        inputs.put(key, map);
        synch.put(key, \"\");
    }

    public void destroyNetToken(String key)
    {
        inputs.remove(key);
        synch.remove(key);
    }
}"

      end

      File.open("#{genPath}\\#{transName}Bean.java", 'w') do |f|
        f.puts transBean
      end
    end

    manager = elementNets[en];

    elementNodes = manager.xpath('net/places/@name').to_a + manager.xpath('net/transitions/@name').to_a

    variablesBlock = ""
    createBlock = ""
    destroyBlock = ""
    (0..elementNodes.count - 1).each do |i|
      variablesBlock << "@EJB\n#{elementNodes[i]}Bean #{elementNodes[i]};\n"
      createBlock << "#{elementNodes[i]}.createNetToken(token);\n"
      destroyBlock << "#{elementNodes[i]}.destroyNetToken(id);\n"
    end

    markupsBlock = ""
    markups = manager.xpath('elementNetMarkeds')
    (0..markups.count - 1).each do |i|
      markupsBlock << "if(markup.equals(\"#{markups[i]['id']}\"))
                        {\n"
      placeIds = markups.xpath('marking/map/@place')
      (0..placeIds.count - 1).each do |j|
        placeName = manager.xpath("net/places[@id='#{placeIds[j].to_s.delete('#')}']/@name").to_s
        markupsBlock << "#{placeName}.createToken(token);\n"
      end
      markupsBlock << "}"
    end


    managerBean = "package #{package};

import java.util.ArrayList;
import java.util.List;
import javax.annotation.PostConstruct;
import javax.ejb.EJB;

import javax.ejb.Singleton;
import javax.ejb.Startup;


@Startup
@Singleton
public class #{manager['name']}ManagerBean {

    #{variablesBlock}

    List<String> list = new ArrayList<String>();
    String type = \"net\";
    String name = \"#{manager['name']}\";
    Integer idCounter = 0;
    Integer activeNets;

    @PostConstruct
    void init() {
        activeNets = 0;
    }

    public String createToken(String markup) {
        idCounter++;
        String token = (type + \"_\" + name + \"_\" + idCounter);

        #{createBlock}


    #{markupsBlock}

        activeNets++;

        return token;
    }

    public void removeToken(String id) {
        activeNets--;
        #{destroyBlock}
    }

    public Integer getActiveNets()
    {
        return activeNets;
    }
}
"

    File.open("#{genPath}\\#{manager['name']}ManagerBean.java", 'w') do |f|
      f.puts managerBean
    end

  end
end

def compile(jdkPath, glassfishPath, filepath)
  filePath = filepath
  fileDir = filePath.slice(0..filePath.rindex('\\'))

  f = File.open(filePath)
  doc = Nokogiri::XML(f)
  f.close

  doc = doc.xpath('npnets:PetriNetNestedMarked')
  systemNet = doc.xpath('child::net')[0]
  package = systemNet.xpath('netSystem')[0]['name'].gsub(' ', '_')

  genPath = fileDir + "output\\classes"
  if (!File.directory?(genPath))
    FileUtils.mkdir_p genPath
  end

  Dir.chdir("#{fileDir}output/java") do
    system "\"#{jdkPath}\\bin\\javac\" -cp \"#{glassfishPath}\\glassfish\\lib\\javaee.jar\" -d \"#{genPath}\" #{package}/*.java"
  end

end

def pack(jdkPath, filepath)
  filePath = filepath
  fileDir = filePath.slice(0..filePath.rindex('\\'))

  f = File.open(filePath)
  doc = Nokogiri::XML(f)
  f.close

  doc = doc.xpath('npnets:PetriNetNestedMarked')
  systemNet = doc.xpath('child::net')[0]
  package = systemNet.xpath('netSystem')[0]['name'].gsub(' ', '_')

  genPath = fileDir + "output"
  if (!File.directory?(genPath))
    FileUtils.mkdir_p genPath
  end

  Dir.chdir("#{fileDir}output/classes") do
    system "\"#{jdkPath}\\bin\\jar\" -cvf \"#{genPath}\\#{package}.jar\" #{package}"
  end

end

def deploy(glassfishPath, filepath)
  filePath = filepath
  fileDir = filePath.slice(0..filePath.rindex('\\'))

  f = File.open(filePath)
  doc = Nokogiri::XML(f)
  f.close

  doc = doc.xpath('npnets:PetriNetNestedMarked')
  systemNet = doc.xpath('child::net')[0]
  package = systemNet.xpath('netSystem')[0]['name'].gsub(' ', '_')

  jarFile = fileDir + "output\\#{package}.jar"

  FileUtils.cp(jarFile, glassfishPath + '\glassfish\domains\domain1\autodeploy')
end

if (ARGV[0] == 'generate')
  generate(ARGV[1].to_s)
elsif (ARGV[0] == 'compile')
  compile(ARGV[1].to_s, ARGV[2].to_s, ARGV[3].to_s)
elsif (ARGV[0] == 'pack')
  pack(ARGV[1].to_s, ARGV[2].to_s)
elsif (ARGV[0] == 'deploy')
  deploy(ARGV[1].to_s, ARGV[2].to_s)
end








