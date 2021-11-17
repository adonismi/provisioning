FROM openjdk:8
ADD petclinic.jar petclinic.jar
ENTRYPOINT ["java", "-jar", "petclinic.jar"]

